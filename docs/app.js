(() => {
  const hostOwner = location.hostname.endsWith(".github.io")
    ? location.hostname.slice(0, -".github.io".length)
    : null;
  const pathRepo = location.pathname.split("/").filter(Boolean)[0];
  const repo = pathRepo || "GhostMark";

  if (!hostOwner) return;

  const repositoryURL = `https://github.com/${hostOwner}/${repo}`;
  const downloadLinks = document.querySelectorAll("[data-download-link]");

  document.querySelectorAll("[data-github-link]").forEach((link) => {
    link.href = repositoryURL;
  });

  fetch(`https://api.github.com/repos/${hostOwner}/${repo}/releases/latest`, {
    headers: { Accept: "application/vnd.github+json" }
  })
    .then((response) => response.ok ? response.json() : Promise.reject())
    .then((release) => {
      const downloadURL = `${repositoryURL}/releases/latest/download/GhostMark.zip`;
      downloadLinks.forEach((link) => {
        link.href = downloadURL;
        link.removeAttribute("aria-disabled");
      });
      document.querySelectorAll("[data-version]").forEach((label) => {
        label.textContent = release.tag_name;
      });
    })
    .catch(() => {
      downloadLinks.forEach((link) => {
        link.removeAttribute("href");
        link.setAttribute("aria-disabled", "true");
      });
      document.querySelectorAll("[data-download-label]").forEach((label) => {
        label.textContent = "首版公證中";
      });
      document.querySelectorAll("[data-notary]").forEach((label) => {
        label.textContent = "準備中";
      });
    });
})();
