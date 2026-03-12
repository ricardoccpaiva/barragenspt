/**
 * Navigate to basin detail (Portuguese basin).
 */
export function navigateToBasin(basinId) {
  const link = document.getElementById("basinDetailLink")
  const target = `/basins/${basinId}`
  if (link) {
    link.setAttribute("href", target)
    link.click()
    return
  }
  window.location.href = target
}

let damCardPatchLink = null

/**
 * Navigate to dam detail (patch/navigate within LiveView).
 */
export function navigateToDam(basinId, damId) {
  let link = document.getElementById("damCardPatchLink")
  if (!link) {
    link = document.createElement("a")
    link.id = "damCardPatchLink"
    link.setAttribute("data-phx-link", "patch")
    link.setAttribute("data-phx-link-state", "push")
    link.style.display = "none"
    document.body.appendChild(link)
    damCardPatchLink = link
  }
  link.href = "/basins/" + basinId + "/dams/" + damId
  link.click()
}
