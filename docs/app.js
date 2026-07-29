(() => {
  const hostOwner = location.hostname.endsWith(".github.io")
    ? location.hostname.slice(0, -".github.io".length)
    : null;
  const pathRepo = location.pathname.split("/").filter(Boolean)[0];
  const repo = pathRepo || "GhostMark";

  if (!hostOwner) return;

  const repositoryURL = `https://github.com/${hostOwner}/${repo}`;
  const downloadURL = `${repositoryURL}/releases/latest/download/GhostMark.dmg`;

  document.querySelectorAll("[data-github-link]").forEach((link) => {
    link.href = repositoryURL;
  });
  document.querySelectorAll("[data-download-link]").forEach((link) => {
    link.href = downloadURL;
  });

  fetch(`https://api.github.com/repos/${hostOwner}/${repo}/releases/latest`, {
    headers: { Accept: "application/vnd.github+json" }
  })
    .then((response) => response.ok ? response.json() : Promise.reject())
    .then((release) => {
      document.querySelectorAll("[data-version]").forEach((label) => {
        label.textContent = release.tag_name;
      });
    })
    .catch(() => {});
})();
