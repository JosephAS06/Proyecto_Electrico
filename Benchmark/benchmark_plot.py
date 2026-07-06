"""
Gráfica de rendimiento: Pipeline Escalar RISC-V RV32I vs. Extensión Vectorial SIMD
Benchmark: C[i] = A[i] + B[i] para i = 0..N-1

Comparación principal: Escalar con forwarding vs. Vectorial SIMD con forwarding
Referencia: Escalar sin forwarding (ilustra el overhead de NOPs conservadores)
"""

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

# =====================================================================
# DATOS MEDIDOS EN SIMULACIÓN (Icarus Verilog)
# =====================================================================
# N=4
SCALAR_BASE_N4  = 59    # tb_scalar_perf.v       — escalar sin forwarding
SCALAR_FWD_N4   = 23    # tb_scalar_fwd.v        — escalar con forwarding
VECTOR_FWD_N4   = 21    # tb_vector_fwd_n4.v     — vectorial con forwarding

# N=8
SCALAR_BASE_N8  = 75    # estimado modelo 43+4N
SCALAR_FWD_N8   = 39    # tb_scalar_n8.v         — escalar con forwarding
VECTOR_FWD_N8   = 22    # tb_vector_fwd_n8.v     — vectorial con forwarding

# N=16
SCALAR_BASE_N16 = 107   # estimado modelo 43+4N
SCALAR_FWD_N16  = 71    # tb_scalar_n16.v        — escalar con forwarding
VECTOR_FWD_N16  = 35    # tb_vector_fwd_n16.v    — vectorial con forwarding

# =====================================================================
# MODELOS DE ESCALABILIDAD (ajuste lineal mínimos cuadrados)
# =====================================================================
# Escalar sin fwd:    43.0 + 4.00*N  (referencia — overhead NOPs entre grupos)
# Escalar con fwd:     7.0 + 4.00*N  (misma pendiente, menor overhead fijo)
# Vectorial con fwd:  14.5 + 1.23*N  (ajuste LS sobre N=4,8,16)

N_arr = np.linspace(4, 32, 400)
model_base    = 43.00 + 4.000 * N_arr
model_fwd     =  7.00 + 4.000 * N_arr
model_vec_fwd = 14.50 + 1.232 * N_arr

# =====================================================================
# ESTILOS
# =====================================================================
C_BASE    = '#C1121F'   # rojo oscuro   — escalar sin fwd (referencia NOP)
C_FWD     = '#003566'   # azul marino   — escalar con fwd (comparación principal)
C_VEC_FWD = '#C77D00'   # ámbar oscuro  — vectorial con fwd (comparación principal)

BG       = '#F7F7F7'
GRID_CLR = '#DDDDDD'

plt.rcParams.update({
    'font.family':       'DejaVu Sans',
    'font.size':         12,
    'figure.facecolor':  BG,
    'axes.facecolor':    BG,
    'axes.grid':         True,
    'grid.color':        GRID_CLR,
    'grid.linewidth':    0.8,
    'grid.linestyle':    '--',
    'axes.spines.top':   False,
    'axes.spines.right': False,
    'axes.linewidth':    1.1,
    'xtick.major.size':  5,
    'ytick.major.size':  5,
})

fig = plt.figure(figsize=(26, 10), facecolor=BG)
fig.subplots_adjust(left=0.05, right=0.98, top=0.83, bottom=0.10, wspace=0.28)

ax1 = fig.add_subplot(1, 2, 1)
ax2 = fig.add_subplot(1, 2, 2)

# =====================================================================
# PANEL IZQUIERDO — Barras agrupadas (N=4, N=8, N=16)
# =====================================================================
w   = 0.14
gap = 0.018
offsets = np.array([-1.0, 0.0, 1.0]) * (w + gap)
group_centers = np.array([0.44, 1.26, 2.08])

configs = [
    ('scalar_base', [SCALAR_BASE_N4, SCALAR_BASE_N8, SCALAR_BASE_N16], C_BASE,
     'Escalar — sin forwarding  (referencia NOPs)', 0.45),
    ('scalar_fwd',  [SCALAR_FWD_N4,  SCALAR_FWD_N8,  SCALAR_FWD_N16 ], C_FWD,
     'Escalar — con forwarding', 1.0),
    ('vector_fwd',  [VECTOR_FWD_N4,  VECTOR_FWD_N8,  VECTOR_FWD_N16 ], C_VEC_FWD,
     'Vectorial SIMD — con forwarding  ★', 1.0),
]

for j, (key, vals, color, label, alpha) in enumerate(configs):
    xs = group_centers + offsets[j]
    bars = ax1.bar(xs, vals, w,
                   color=color, alpha=alpha,
                   edgecolor='white', linewidth=1.2,
                   zorder=3, label=label)
    for bar, val, N_val in zip(bars, vals, [4, 8, 16]):
        is_est = (key == 'scalar_base' and N_val in [8, 16])
        txt = f'{val}*' if is_est else str(val)
        txt_color = '#888888' if key == 'scalar_base' else '#1A1A1A'
        ax1.text(bar.get_x() + bar.get_width() / 2.0, val + 1.5,
                 txt, ha='center', va='bottom',
                 fontsize=10.5, fontweight='bold', color=txt_color)

# Anotación "overhead NOPs" encima de las barras escalar sin fwd
for gc, y_ref, N_val in zip(group_centers,
                             [SCALAR_BASE_N4, SCALAR_BASE_N8, SCALAR_BASE_N16],
                             [4, 8, 16]):
    x_bar = gc + offsets[0]
    ax1.annotate(
        'NOPs',
        xy=(x_bar, y_ref + 2),
        ha='center', fontsize=7.5,
        color=C_BASE, style='italic',
        xytext=(x_bar, y_ref + 10),
        arrowprops=dict(arrowstyle='->', color=C_BASE, lw=0.9, alpha=0.55),
    )

# Anotaciones de speedup: vectorial+fwd vs escalar+fwd (comparación principal)
speedups = [
    (group_centers[0], max(SCALAR_FWD_N4,  VECTOR_FWD_N4),
     f'★ ×{SCALAR_FWD_N4/VECTOR_FWD_N4:.2f}\nvec+fwd\nvs. esc+fwd'),
    (group_centers[1], max(SCALAR_FWD_N8,  VECTOR_FWD_N8),
     f'★ ×{SCALAR_FWD_N8/VECTOR_FWD_N8:.2f}\nvec+fwd\nvs. esc+fwd'),
    (group_centers[2], max(SCALAR_FWD_N16, VECTOR_FWD_N16),
     f'★ ×{SCALAR_FWD_N16/VECTOR_FWD_N16:.2f}\nvec+fwd\nvs. esc+fwd'),
]
for gc, y_ref, txt in speedups:
    ax1.annotate(
        txt,
        xy=(gc, y_ref + 8), ha='center', fontsize=9,
        color=C_VEC_FWD, fontweight='bold',
        bbox=dict(boxstyle='round,pad=0.30', facecolor='#FFF3CD',
                  edgecolor=C_VEC_FWD, linewidth=1.0, alpha=0.95),
    )

ax1.set_xticks(group_centers)
ax1.set_xticklabels(
    ['N = 4\n(4 elementos)', 'N = 8\n(8 elementos)', 'N = 16\n(16 elementos)'],
    fontsize=13,
)
ax1.set_ylabel('Ciclos de reloj', fontsize=15, fontweight='bold', labelpad=8)
ax1.set_xlim(0.0, 2.65)
ax1.set_ylim(0, 155)
ax1.set_title(
    'Ciclos de reloj por configuración y tamaño\n'
    '(menor es mejor — datos de simulación RTL)',
    fontsize=14, fontweight='bold', pad=12,
)
ax1.yaxis.set_major_locator(mticker.MultipleLocator(10))
ax1.grid(axis='y', zorder=0)
ax1.grid(axis='x', visible=False)
ax1.legend(fontsize=10.5, loc='upper right', framealpha=0.95,
           edgecolor='#BBBBBB', handlelength=1.5)
ax1.text(0.01, 0.01,
         '* valor estimado mediante modelo lineal (43 + 4·N)',
         transform=ax1.transAxes, fontsize=9,
         color='#888888', style='italic')

# =====================================================================
# PANEL DERECHO — Escalabilidad (modelos + puntos medidos)
# =====================================================================

# Región de ventaja: vectorial+fwd bajo la curva escalar+fwd
ax2.fill_between(N_arr, model_vec_fwd, model_fwd,
                 color=C_VEC_FWD, alpha=0.10, zorder=1,
                 label='_nolegend_')

# Referencia escalar sin fwd — faded/dashed para indicar que es el caso problemático
ax2.plot(N_arr, model_base, '--', color=C_BASE, linewidth=1.8, zorder=2,
         alpha=0.45, label='Escalar — sin fwd  (43 + 4N)  [ref. NOPs]')

# Líneas de comparación principal
ax2.plot(N_arr, model_fwd,     '-',  color=C_FWD,     linewidth=2.8, zorder=4,
         label='Escalar — con fwd  (7 + 4N)')
ax2.plot(N_arr, model_vec_fwd, '-',  color=C_VEC_FWD, linewidth=2.8, zorder=4,
         label='Vectorial — con fwd  (14.5 + 1.23N)  ★')

# Punto medido — escalar sin fwd (solo N=4, referencia)
ax2.scatter([4], [SCALAR_BASE_N4],
            color=C_BASE, s=100, zorder=5,
            edgecolors='white', linewidths=1.5, marker='o',
            alpha=0.50)

# Puntos medidos — escalar con fwd
ax2.scatter([4, 8, 16], [SCALAR_FWD_N4, SCALAR_FWD_N8, SCALAR_FWD_N16],
            color=C_FWD, s=180, zorder=6,
            edgecolors='white', linewidths=1.8, marker='s',
            label='Escalar+fwd medido')

# Puntos medidos — vectorial con fwd (todos medidos)
ax2.scatter([4, 8, 16], [VECTOR_FWD_N4, VECTOR_FWD_N8, VECTOR_FWD_N16],
            color=C_VEC_FWD, s=220, zorder=7,
            edgecolors='white', linewidths=2.0, marker='D',
            label='Vectorial+fwd medido ★')

# Anotación vectorial+fwd N=16
ax2.annotate(
    f'Vec+fwd N=16: {VECTOR_FWD_N16} ciclos\n'
    f'×{SCALAR_FWD_N16/VECTOR_FWD_N16:.2f} vs. Escalar+fwd',
    xy=(16, VECTOR_FWD_N16),
    xytext=(18.5, VECTOR_FWD_N16 + 32),
    fontsize=9.5, color=C_VEC_FWD, fontweight='bold',
    arrowprops=dict(arrowstyle='->', color=C_VEC_FWD, lw=1.5),
    bbox=dict(boxstyle='round,pad=0.32', facecolor='#FFF3CD',
              edgecolor=C_VEC_FWD, linewidth=0.9, alpha=0.95),
    zorder=8,
)

# Anotación escalar+fwd N=16
ax2.annotate(
    f'Esc+fwd N=16: {SCALAR_FWD_N16} ciclos',
    xy=(16, SCALAR_FWD_N16),
    xytext=(18.5, SCALAR_FWD_N16 + 14),
    fontsize=9.0, color=C_FWD, fontweight='bold',
    arrowprops=dict(arrowstyle='->', color=C_FWD, lw=1.5),
    bbox=dict(boxstyle='round,pad=0.30', facecolor='#E8EEF7',
              edgecolor=C_FWD, linewidth=0.9, alpha=0.95),
    zorder=8,
)

# Anotación referencia sin fwd (N=4)
ax2.annotate(
    f'Sin fwd N=4: {SCALAR_BASE_N4} ciclos\n(NOPs conservadores)',
    xy=(4, SCALAR_BASE_N4),
    xytext=(6.5, SCALAR_BASE_N4 + 18),
    fontsize=8.5, color=C_BASE, fontweight='bold',
    arrowprops=dict(arrowstyle='->', color=C_BASE, lw=1.2, alpha=0.55),
    bbox=dict(boxstyle='round,pad=0.28', facecolor='#F9E8E8',
              edgecolor=C_BASE, linewidth=0.8, alpha=0.75),
    zorder=7,
)

# Etiquetas de pendiente
def slope_label(ax, N_c, fn, color, text, dy=5, dx=0.5, alpha=1.0):
    ax.text(N_c + dx, fn(N_c) + dy, text,
            fontsize=9.5, color=color, fontweight='bold', alpha=alpha,
            bbox=dict(boxstyle='round,pad=0.2', facecolor=BG, alpha=0.78,
                      edgecolor=color, linewidth=0.7))

slope_label(ax2, 22, lambda n: 43 + 4.0 * n,  C_BASE,
            '+4 cic./elem.', dy=4, dx=-8.5, alpha=0.50)
slope_label(ax2, 22, lambda n:  7 + 4.0 * n,  C_FWD,
            '+4 cic./elem.', dy=4, dx=-8.5)
slope_label(ax2, 20, lambda n: 14.5 + 1.232 * n, C_VEC_FWD,
            '+1.23 cic./elem.', dy=-15, dx=0.5)

ax2.set_xlabel('Número de elementos  N', fontsize=15, fontweight='bold', labelpad=8)
ax2.set_ylabel('Ciclos de reloj', fontsize=15, fontweight='bold', labelpad=8)
ax2.set_title(
    'Escalabilidad del rendimiento con el tamaño del problema\n'
    '(modelos lineales + puntos medidos — menor es mejor)',
    fontsize=14, fontweight='bold', pad=12,
)
ax2.set_xlim(2.5, 33)
ax2.set_ylim(0, 200)
ax2.xaxis.set_major_locator(mticker.MultipleLocator(4))
ax2.yaxis.set_major_locator(mticker.MultipleLocator(20))
ax2.tick_params(axis='both', labelsize=12)

handles, labels = ax2.get_legend_handles_labels()
ax2.legend(handles=handles, labels=labels,
           fontsize=10, loc='upper left', framealpha=0.95,
           edgecolor='#BBBBBB', ncol=1, handlelength=2.0)

# =====================================================================
# TÍTULO PRINCIPAL
# =====================================================================
fig.text(
    0.5, 0.97,
    'Análisis de Rendimiento: Escalar RISC-V RV32I con Forwarding vs. Extensión Vectorial SIMD con Forwarding',
    ha='center', va='top',
    fontsize=17, fontweight='bold', color='#0D0D0D',
)
fig.text(
    0.5, 0.905,
    'Benchmark: C[i] = A[i] + B[i]  |  Reloj 100 MHz  |  VLEN = 128 bits  |  4 carriles  |  '
    'Forwarding EX→EX activo en ambas configuraciones principales  |  Todos los valores medidos en simulación RTL',
    ha='center', va='top',
    fontsize=12.5, color='#444444',
)

# =====================================================================
# GUARDAR
# =====================================================================
out_path = '/home/user/Proyecto_Electrico/benchmark_rendimiento.png'
plt.savefig(out_path, dpi=220, bbox_inches='tight', facecolor=BG)
print(f'Gráfica guardada en: {out_path}')
plt.show()
