#!/usr/bin/env python3
"""Construye la LUT de cargas aerodinamicas a partir de resultados.csv.

Entrada : resultados.csv (barrido CFD estatico: delta, mach, aoa -> Cl, Cd, CmPitch, ChHinge, HingeMoment_Nm)
Salidas : lut_cargas.csv, lut_cargas.mat, figuras/*.png, LUT_cargas.md

Uso: python build_lut.py [ruta/resultados.csv] [carpeta_salida]
"""
import os
import sys

import matplotlib
import warnings

import numpy as np
import pandas as pd
from scipy.interpolate import RegularGridInterpolator
from scipy.io import loadmat, savemat

warnings.filterwarnings("ignore", message="All-NaN slice")
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

SRC = sys.argv[1] if len(sys.argv) > 1 else "/mnt/user-data/uploads/resultados.csv"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/mnt/user-data/outputs/LUT_cargas"
os.makedirs(os.path.join(OUT, "figuras"), exist_ok=True)

VARS = ["Cl", "Cd", "CmPitch", "ChHinge"]
# paridad frente a (delta, alpha) -> (-delta, -alpha) en perfil simetrico
SIGN = {"Cl": -1, "Cd": +1, "CmPitch": -1, "ChHinge": -1}

# ---------------------------------------------------------------- 1. carga y grilla
raw = pd.read_csv(SRC).sort_values(["delta_deg", "mach", "aoa_deg"]).reset_index(drop=True)
dl = np.sort(raw.delta_deg.unique())
ma = np.sort(raw.mach.unique())
al = np.sort(raw.aoa_deg.unique())
nD, nM, nA = len(dl), len(ma), len(al)
assert len(raw) == nD * nM * nA, "la grilla CFD no es completa"
assert not raw.isna().any().any() and not raw.duplicated(["delta_deg", "mach", "aoa_deg"]).any()
A = {v: raw[v].values.reshape(nD, nM, nA) for v in VARS}
HM_raw = raw["HingeMoment_Nm"].values.reshape(nD, nM, nA)
rng = {v: float(np.ptp(A[v])) for v in VARS}

# ---------------------------------------------------------------- 2. HingeMoment = K * M^2 * ChHinge
x = (ma[None, :, None] ** 2) * A["ChHinge"]
K = float((HM_raw * x).sum() / (x * x).sum())
k_rel_err = float(np.abs(HM_raw - K * x).max() / np.abs(HM_raw).max())

# ---------------------------------------------------------------- 3. simetria (solo pares con -alpha en la grilla)
al_idx = {round(a, 6): i for i, a in enumerate(al)}
dl_idx = {round(d, 6): i for i, d in enumerate(dl)}
pairs = []
for i, d in enumerate(dl):
    for k, a in enumerate(al):
        if round(-a, 6) in al_idx and round(-d, 6) in dl_idx and (d, a) > (-d, -a):
            pairs.append((i, dl_idx[round(-d, 6)], k, al_idx[round(-a, 6)]))
sym = {}
for v in VARS:
    # paridad impar: f(d,a) + f(-d,-a) = 0 ; paridad par: f(d,a) - f(-d,-a) = 0
    r = np.array([[A[v][i, m, k] - SIGN[v] * A[v][i2, m, k2]
                   for m in range(nM)] for i, i2, k, k2 in pairs])
    sym[v] = dict(mean=float(np.abs(r).mean()), max=float(np.abs(r).max()), pct=100 * float(np.abs(r).max()) / rng[v])
n_pairs = len(pairs) * nM

# ---------------------------------------------------------------- 4. extension por simetria en alpha
new_a = sorted({round(-a, 6) for a in al if -a < al.min() - 1e-9})
al_ext = np.array(new_a + list(al))
nAe = len(al_ext)
E = {}
origen = np.zeros((nD, nM, nAe), dtype=np.int8)  # 0 = CFD, 1 = simetria
for v in VARS:
    arr = np.empty((nD, nM, nAe))
    for k, a in enumerate(al_ext):
        if round(a, 6) in al_idx:
            arr[:, :, k] = A[v][:, :, al_idx[round(a, 6)]]
            origen[:, :, k] = 0
        else:
            arr[:, :, k] = SIGN[v] * A[v][::-1, :, al_idx[round(-a, 6)]]
            origen[:, :, k] = 1
    E[v] = arr
HM_ext = K * (ma[None, :, None] ** 2) * E["ChHinge"]
cfd_mask = origen == 0
hm_check = float(np.abs(HM_ext[:, :, [round(a, 6) in al_idx for a in al_ext]] - HM_raw).max())

# ---------------------------------------------------------------- 5. salidas CSV y MAT
D3, M3, A3 = np.meshgrid(dl, ma, al_ext, indexing="ij")
lut = pd.DataFrame({
    "delta_deg": D3.ravel(), "mach": M3.ravel(), "aoa_deg": A3.ravel(),
    **{v: E[v].ravel() for v in VARS},
    "HingeMoment_Nm": HM_ext.ravel(),
    "origen": np.where(origen.ravel() == 0, "cfd", "simetria"),
})
lut.to_csv(os.path.join(OUT, "lut_cargas.csv"), index=False, float_format="%.10g")
savemat(os.path.join(OUT, "lut_cargas.mat"), {
    "delta_deg": dl, "mach": ma, "aoa_deg": al_ext,
    **{v: E[v] for v in VARS},
    "HingeMoment_Nm": HM_ext, "K_hinge": K, "origen": origen,
})

# verificacion de ida y vuelta
L = loadmat(os.path.join(OUT, "lut_cargas.mat"))
assert np.array_equal(L["ChHinge"], E["ChHinge"]) and L["ChHinge"].shape == (nD, nM, nAe)
interp = {v: RegularGridInterpolator((dl, ma, al_ext), E[v], method="linear") for v in VARS}
pts = np.column_stack([D3.ravel(), M3.ravel(), A3.ravel()])
node_err = max(float(np.abs(interp[v](pts) - E[v].ravel()).max()) for v in VARS)
rs = np.random.default_rng(0)
q = np.column_stack([rs.uniform(-15, 15, 2000), rs.uniform(ma.min(), ma.max(), 2000), rs.uniform(-4, 4, 2000)])
qm = q * np.array([-1, 1, -1])
sym_interp = float(np.abs(interp["ChHinge"](q) + interp["ChHinge"](qm)).max())

# ---------------------------------------------------------------- 6. error de interpolacion (leave-one-out por eje)
def loo(arr, axis):
    e = np.full(arr.shape, np.nan)
    a = np.moveaxis(arr, axis, 0)
    ee = np.moveaxis(e, axis, 0)
    ee[1:-1] = np.abs(a[1:-1] - 0.5 * (a[:-2] + a[2:]))
    return e

axes_names = {0: "delta", 1: "mach", 2: "alpha"}
loo_stats = {}
for v in ["ChHinge", "Cl"]:
    for ax in (0, 1, 2):
        e = loo(A[v], ax)
        flat = e[~np.isnan(e)]
        idx = np.unravel_index(np.nanargmax(e), e.shape)
        loo_stats[(v, ax)] = dict(
            med=100 * float(np.median(flat)) / rng[v], p95=100 * float(np.percentile(flat, 95)) / rng[v],
            max=100 * float(flat.max()) / rng[v], at=(dl[idx[0]], ma[idx[1]], al[idx[2]]))
e_alpha_Ch = loo(A["ChHinge"], 2)
worst = []
order = np.argsort(np.nan_to_num(e_alpha_Ch, nan=-1).ravel())[::-1][:8]
for o in order:
    i, m, k = np.unravel_index(o, e_alpha_Ch.shape)
    worst.append((dl[i], ma[m], al[k], A["ChHinge"][i, m, k], e_alpha_Ch[i, m, k] / 4))

# ---------------------------------------------------------------- 7. dependencia en Mach de ChHinge
mach_rng = np.ptp(A["ChHinge"], axis=1)  # (nD, nA)
mach_stats = dict(med=float(np.median(mach_rng)), p95=float(np.percentile(mach_rng, 95)), max=float(mach_rng.max()))
mi = np.unravel_index(np.argmax(mach_rng), mach_rng.shape)
mach_at = (dl[mi[0]], al[mi[1]])
mach_stats["max_pct"] = 100 * mach_stats["max"] / rng["ChHinge"]
mach_stats["med_pct"] = 100 * mach_stats["med"] / rng["ChHinge"]

# ---------------------------------------------------------------- 8. figuras
j = int(np.argmin(np.abs(ma - 0.2)))
cmap = plt.get_cmap("coolwarm")
fig, axs = plt.subplots(2, 2, figsize=(11, 8), sharex=True)
labels = {"Cl": "Cl", "Cd": "Cd", "CmPitch": "CmPitch", "ChHinge": "ChHinge"}
for ax, v in zip(axs.ravel(), VARS):
    for i, d in enumerate(dl):
        c = cmap(i / (nD - 1))
        ax.plot(al_ext[origen[i, j, :] == 0], E[v][i, j, origen[i, j, :] == 0], "o-", ms=3, color=c, label=f"δ={d:g}°")
        mm = origen[i, j, :] == 1
        kk = np.where(mm)[0]
        if len(kk):
            kk = np.r_[kk, kk[-1] + 1]
            ax.plot(al_ext[kk], E[v][i, j, kk], "--", color=c, alpha=0.6)
    ax.set_ylabel(labels[v]); ax.grid(alpha=0.3)
for ax in axs[1]:
    ax.set_xlabel("AoA [°]")
axs[0, 0].legend(ncol=2, fontsize=8)
fig.suptitle(f"Coeficientes vs AoA, Mach = {ma[j]:g}  (línea continua: CFD, discontinua: extensión por simetría)")
fig.tight_layout(); fig.savefig(os.path.join(OUT, "figuras", "fig1_coef_vs_aoa.png"), dpi=130); plt.close(fig)

fig, ax = plt.subplots(figsize=(7, 4.5))
for a in (0, 4, 8, 12):
    k = al_idx[a]
    ax.plot(dl, A["ChHinge"][:, j, k], "o-", label=f"AoA={a}°")
ax.set_xlabel("δ [°]"); ax.set_ylabel("ChHinge"); ax.grid(alpha=0.3); ax.legend()
ax.set_title(f"ChHinge vs δ, Mach = {ma[j]:g}")
fig.tight_layout(); fig.savefig(os.path.join(OUT, "figuras", "fig2_chhinge_vs_delta.png"), dpi=130); plt.close(fig)

fig, ax = plt.subplots(figsize=(8, 4.5))
em = np.nanmax(e_alpha_Ch, axis=1) / 4 / rng["ChHinge"] * 100  # (nD, nA), max sobre Mach, aprox. error en el punto medio
im = ax.imshow(em.T, origin="lower", aspect="auto", cmap="viridis",
               extent=[-17.5, 17.5, al[0] - 1, al[-1] + 1])
ax.set_xticks(dl); ax.set_yticks(al)
ax.set_xlabel("δ [°]"); ax.set_ylabel("AoA [°]")
fig.colorbar(im, label="error lineal estimado en α [% del rango de ChHinge]")
ax.set_title("Error de interpolación lineal en α (máx. sobre Mach)")
fig.tight_layout(); fig.savefig(os.path.join(OUT, "figuras", "fig3_error_interpolacion.png"), dpi=130); plt.close(fig)

# ---------------------------------------------------------------- 9. documento .md
def fmt_pt(t):
    return f"δ={t[0]:g}°, M={t[1]:g}, α={t[2]:g}°"

n_total = len(lut)
ic, kc = int(np.argmax(dl)), int(np.argmax(al))
def n_nonmono(v):
    x = np.diff(A[v], axis=1)
    return int((~(np.all(x >= 0, axis=1) | np.all(x <= 0, axis=1))).sum())
nm_Cd, nm_Ch, n_combo = n_nonmono("Cd"), n_nonmono("ChHinge"), nD * nA
corner_rows = "\n".join(
    f"| {ma[m]:g} | {A['Cl'][ic, m, kc]:.4f} | {A['Cd'][ic, m, kc]:.4f} | {A['ChHinge'][ic, m, kc]:.5f} |"
    for m in range(nM))
n_sym = int((origen == 1).sum())
Sc_isa = K / (0.5 * 1.225 * 340.294 ** 2)
sym_rows = "\n".join(
    f"| {v} | {sym[v]['mean']:.2e} | {sym[v]['max']:.2e} | {sym[v]['pct']:.2f} % |" for v in VARS)
loo_rows = "\n".join(
    f"| {v} | {axes_names[ax]} | {s['med']:.3f} % | {s['p95']:.3f} % | {s['max']:.2f} % | {fmt_pt(s['at'])} |"
    for (v, ax), s in loo_stats.items())
worst_rows = "\n".join(
    f"| {fmt_pt(w[:3])} | {w[3]:.5f} | {w[4]:.2e} ({100*w[4]/rng['ChHinge']:.2f} %) |" for w in worst)

md = f"""# LUT de cargas aerodinámicas (barrido CFD estático)

Tabla de búsqueda para el banco de ensayos de actuadores de superficies de control. Se construye a partir de
`resultados.csv` ({len(raw)} simulaciones CFD estáticas) y entrega los coeficientes aerodinámicos y el momento de
bisagra en función de **δ** (deflexión de la superficie), **Mach** y **AoA**.

## 1. Archivos

| Archivo | Contenido |
|---|---|
| `lut_cargas.csv` | LUT en formato largo ({n_total} filas). Columna `origen`: `cfd` o `simetria` |
| `lut_cargas.mat` | LUT para MATLAB: ejes `delta_deg`, `mach`, `aoa_deg`; arreglos 3D `Cl`, `Cd`, `CmPitch`, `ChHinge`, `HingeMoment_Nm` con dimensiones **(δ, Mach, AoA)** = ({nD}, {nM}, {nAe}); `K_hinge`; `origen` |
| `build_lut.py` | Script que reproduce todo (LUT, validaciones, figuras y este documento) |
| `figuras/` | Gráficos referenciados abajo |

## 2. Estructura de la LUT

| Eje | Valores | Paso | Nº |
|---|---|---|---|
| δ [°] | {dl.min():g} a {dl.max():g} | {np.diff(dl)[0]:g} | {nD} |
| Mach | {ma.min():g} a {ma.max():g} | {np.diff(ma)[0]:g} | {nM} |
| AoA [°] (CFD) | {al.min():g} a {al.max():g} | {np.diff(al)[0]:g} | {nA} |
| AoA [°] (LUT extendida) | {al_ext.min():g} a {al_ext.max():g} | {np.diff(al_ext)[0]:g} | {nAe} |

Variables: `Cl`, `Cd`, `CmPitch`, `ChHinge` (adimensionales) y `HingeMoment_Nm` (N·m).
Los {len(raw)} puntos de CFD se conservan **sin modificar**; los {n_sym} puntos restantes
({new_a[0]:g}° ≤ AoA ≤ {new_a[-1]:g}°) provienen de la simetría del perfil (sección 4).

## 3. Datos de origen y verificación de la grilla

- Grilla completa: {nD} × {nM} × {nA} = {nD*nM*nA} puntos, sin valores nulos ni duplicados.
- Orden de datos: se ordenó por (δ, Mach, AoA) antes de armar los arreglos 3D.

## 4. Extensión del rango de AoA por simetría

El perfil es simétrico, por lo que (δ, α) y (−δ, −α) son configuraciones espejo. Para los puntos nuevos:

- `Cl`, `CmPitch`, `ChHinge`: f(δ, M, α) = −f(−δ, M, −α)
- `Cd`: f(δ, M, α) = +f(−δ, M, −α)

Esto se aplica solo donde falta CFD (AoA < {al.min():g}°). En la zona donde existen ambos (AoA entre
{al.min():g}° y {-al.min():g}°) se mantiene el dato CFD. **Los puntos extendidos heredan el error numérico del
punto CFD espejo** y no son simulaciones independientes: conviene marcarlos como tales (columna `origen`).

Comprobación de la simetría con los datos CFD ({n_pairs} pares espejo disponibles, con AoA entre
{al.min():g}° y {-al.min():g}°):

| Variable | Residuo medio | Residuo máx. | Máx. como % del rango |
|---|---|---|---|
{sym_rows}

## 5. Momento de bisagra

`HingeMoment_Nm` en el CSV original cumple **HingeMoment_Nm = K · Mach² · ChHinge**, con

**K = {K:.4f} N·m** (error relativo máximo del ajuste: {k_rel_err:.1e}).

Es decir, el momento dimensional solo agrega la presión dinámica; la información aerodinámica está en `ChHinge`.
K = ½·ρ·a²·(S·c) para los valores de referencia usados al post-procesar. Como chequeo de plausibilidad:
si usaste ρ = 1.225 kg/m³ y a = 340.294 m/s (ISA nivel del mar), resulta S·c = {Sc_isa:.5f} m³;
verifícalo contra tu post-procesado (ver pendientes, sección 10).

En la LUT, `HingeMoment_Nm` se recalcula como K·M²·ChHinge para todos los puntos (en los puntos CFD coincide con el
original, diferencia máxima {hm_check:.1e} N·m). Para emular otras condiciones (otra altitud, otra velocidad,
otra escala) usa `ChHinge` y recalcula el momento con tu propia presión dinámica en vez de `HingeMoment_Nm`.

**Dependencia de ChHinge con Mach:** en este rango la variación de ChHinge entre M = {ma.min():g} y M = {ma.max():g}
(a δ y AoA fijos) tiene mediana {mach_stats['med']:.1e} ({mach_stats['med_pct']:.2f} % del rango total de ChHinge)
y máximo {mach_stats['max']:.1e} ({mach_stats['max_pct']:.1f} %) en δ={mach_at[0]:g}°, α={mach_at[1]:g}°.
Casi toda la variación de `HingeMoment_Nm` con Mach es, por tanto, el factor M².

## 6. Forma de las curvas

![Coeficientes vs AoA](figuras/fig1_coef_vs_aoa.png)

![ChHinge vs delta](figuras/fig2_chhinge_vs_delta.png)

## 7. Error de interpolación esperado

Se estimó con *leave-one-out* sobre los datos CFD: se quita cada punto interior, se interpola linealmente con sus
dos vecinos a lo largo de un eje y se compara con el valor simulado. Como ese vecino está a doble distancia, el error
de ese ensayo es unas 4 veces mayor que el error máximo de interpolación lineal dentro de una celda de la grilla
(aproximación válida en zonas suaves). Errores expresados como % del rango total de la variable
(ChHinge: {rng['ChHinge']:.4f}; Cl: {rng['Cl']:.3f}).

| Variable | Eje | Mediana | P95 | Máx. | Punto del máximo |
|---|---|---|---|---|---|
{loo_rows}

Puntos con mayor error en α para ChHinge (error de celda estimado = LOO / 4):

| Punto | ChHinge | Error de celda estimado |
|---|---|---|
{worst_rows}

![Error de interpolación](figuras/fig3_error_interpolacion.png)

Lectura: la tabla es casi lineal en la mayor parte del dominio, y el error se concentra en δ grande con AoA alto, donde
las curvas dejan de ser lineales (compatible con el inicio de separación del flujo; esto es una hipótesis hasta
revisar la convergencia de esos casos). Si se aumenta la densidad del barrido, es ahí donde más rinde.

Los puntos de borde (δ = ±{dl.max():g}° y α = {al.max():g}°) no se pueden evaluar con este método, y justo ahí está el
comportamiento más irregular. En δ = {dl[ic]:g}°, α = {al[kc]:g}° Cd cae y luego sube con Mach, y ChHinge invierte su
tendencia; con Mach creciente, Cd es no monótono solo en {nm_Cd} de las {n_combo} combinaciones (δ, α) y ChHinge en {nm_Ch}
(en las demás, con variaciones mucho menores), y ninguna otra tiene una amplitud comparable:

| Mach | Cl | Cd | ChHinge |
|---|---|---|---|
{corner_rows}

Es la zona a revisar primero (convergencia de la solución, sensibilidad a la malla, posible flujo separado/inestable)
antes de confiar en la tabla ahí; conviene limitar el envelope del banco o densificar esa esquina.

## 8. Uso

**Reglas generales:** interpolación lineal trilineal; fuera del rango (δ, Mach, AoA) no hay extrapolación
(devolver NaN y que el banco sature o dispare una alarma).

MATLAB:

```matlab
L  = load('lut_cargas.mat');
F  = griddedInterpolant({{L.delta_deg(:), L.mach(:), L.aoa_deg(:)}}, L.ChHinge, 'linear', 'none');
Ch = F(7, 0.22, 3.5);                  % delta [deg], Mach, AoA [deg]
HM = L.K_hinge * 0.22^2 * Ch;          % momento de bisagra [N m] con la q de la CFD
```

Python:

```python
import numpy as np, pandas as pd
from scipy.interpolate import RegularGridInterpolator
t = pd.read_csv("lut_cargas.csv").sort_values(["delta_deg", "mach", "aoa_deg"])
d, m, a = (np.sort(t[c].unique()) for c in ("delta_deg", "mach", "aoa_deg"))
Ch = t["ChHinge"].values.reshape(len(d), len(m), len(a))
F = RegularGridInterpolator((d, m, a), Ch, bounds_error=False, fill_value=np.nan)
F([[7.0, 0.22, 3.5]])
```

Verificaciones hechas con `build_lut.py`: el interpolador reproduce los {n_total} nodos (error máx. {node_err:.1e});
el archivo `.mat` se recarga idéntico; para ChHinge, la interpolación en 2000 puntos aleatorios espejo (δ, M, α) vs
(−δ, M, −α) con |α| ≤ 4° da una asimetría máxima de {sym_interp:.1e}. El código MATLAB de arriba **no se ejecutó**
(no hay MATLAB/Octave en el entorno de generación): pruébalo con un punto conocido de la tabla.

## 9. Limitaciones

- **Cuasi-estática:** no incluye efectos no estacionarios ni histéresis. Para un escenario (δ(t), α(t), M(t)) se evalúa
  la tabla instante a instante.
- **Zona de separación:** con δ y AoA altos la solución estática puede ser poco confiable (convergencia, oscilaciones);
  conviene revisar esos casos antes de usarlos como referencia (sobre todo δ = {dl.max():g}°, α = {al.max():g}°, ver sección 7).
- **Rango cubierto:** δ ∈ [{dl.min():g}°, {dl.max():g}°], Mach ∈ [{ma.min():g}, {ma.max():g}], AoA ∈ [{al_ext.min():g}°, {al_ext.max():g}°] (con extensión por simetría; CFD real en [{al.min():g}°, {al.max():g}°]).
- **Puntos por simetría:** no son simulaciones independientes (sección 4).

## 10. Pendientes por completar

Estos datos no se pueden deducir del CSV; conviene registrarlos aquí para que la LUT sea trazable:

| Pendiente | Valor |
|---|---|
| Convención de signo de δ, α y ChHinge | COMPLETAR |
| Definición de ChHinge (normalización, S y c de referencia, eje de bisagra) | COMPLETAR |
| ρ y a de referencia usadas para el momento (para verificar K) | COMPLETAR |
| Dimensionalidad del caso (2D por unidad de envergadura o 3D) y envergadura de la superficie | COMPLETAR |
| Solver, modelo de turbulencia y criterio de convergencia | COMPLETAR |
| Estudio de independencia de malla y validación contra datos del NACA 0012 | COMPLETAR |
"""
with open(os.path.join(OUT, "LUT_cargas.md"), "w", encoding="utf-8") as f:
    f.write(md)

print("OK", n_total, "filas;", n_sym, "por simetria; K =", K)
print("sim:", {v: round(sym[v]['pct'], 3) for v in VARS}, "pares", n_pairs)
print("node_err", node_err, "sym_interp", sym_interp, "hm_check", hm_check, "k_rel_err", k_rel_err)
print("mach", mach_stats, mach_at)
for k, s in loo_stats.items():
    print(k, {a: (round(b, 3) if not isinstance(b, tuple) else b) for a, b in s.items()})
print(worst[:3])
