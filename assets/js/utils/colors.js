/**
 * Storage capacity color scale (aligned with app.css .legend-0-20 … .legend-81-100).
 * Single source of truth for basin/dam capacity colors in DOM, map fills, and map circles.
 */

const DEFAULT_GRAY = '#94a3b8'

// For getStorageColor: (max value in range, color). 0–20, 21–40, 41–50, 51–60, 61–80, 81–100
const CAPACITY_RANGES = [
  [20, '#ff675c'],
  [40, '#ffc34a'],
  [50, '#ffe99c'],
  [60, '#c2faaa'],
  [80, '#a6d8ff'],
  [100, '#1c9dff']
]

// For MapLibre step: (min threshold, color). value >= threshold gets color.
const STEP_THRESHOLDS = [
  [21, '#ffc34a'],
  [41, '#ffe99c'],
  [51, '#c2faaa'],
  [61, '#a6d8ff'],
  [81, '#1c9dff']
]
const STEP_DEFAULT = '#ff675c'

/**
 * Returns hex color for a capacity percentage (0–100). For DOM/legends.
 */
export function getStorageColor(percentage) {
  const value = Number(percentage)
  if (Number.isNaN(value)) return DEFAULT_GRAY
  const clamped = Math.max(0, Math.min(100, value))
  for (const [maxInclusive, color] of CAPACITY_RANGES) {
    if (clamped <= maxInclusive) return color
  }
  return CAPACITY_RANGES[CAPACITY_RANGES.length - 1][1]
}

/**
 * MapLibre step expression for circle/fill paint: value >= threshold gets color.
 */
export function capacityColorStepExpression(property = 'pct') {
  const exp = ['step', ['get', property], STEP_DEFAULT]
  STEP_THRESHOLDS.forEach(([threshold, color]) => {
    exp.push(threshold, color)
  })
  return exp
}

export const DAMS_CIRCLE_COLOR_GRAY = DEFAULT_GRAY
