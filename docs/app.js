(() => {
  const copy = {
    en: {
      title: "GhostMark — Image markup for Claude Code",
      skip: "Skip to content",
      primaryNav: "Primary navigation",
      navSetup: "Setup",
      navSource: "Source",
      kicker: "A macOS utility for Claude Code",
      headline: "Draw on it<br>before Claude<br>sees it.",
      lede: "Paste an image in your terminal. GhostMark opens a focused markup window, then sends the finished image back to Claude Code.",
      download: "Download GhostMark",
      viewSource: "View source",
      latestRelease: "Latest release",
      notarized: "Apple notarized",
      preparing: "Preparing signed installer",
      editorPreview: "Animated preview of GhostMark opening over Claude Code, marking an image, and sending it back",
      done: "Done",
      paste: "Paste",
      mark: "Mark",
      send: "Send",
      setupLabel: "Setup",
      setupTitle: "Install once.<br>Keep using your terminal.",
      stepOne: "Open the signed <strong>.pkg</strong> installer.",
      stepTwo: "Allow Accessibility access when GhostMark asks.",
      stepThree: "Paste an image while Claude Code is active.",
      productDetails: "Product details",
      worksLabel: "Works where you work",
      worksText: "Ghostty, Terminal, iTerm2, Warp, and embedded terminals.",
      privacyLabel: "Private by design",
      privacyText: "Your images stay on your Mac. No account, analytics, or uploads.",
      openSource: "Open source under the",
      privacyLink: "Privacy",
      switchLanguage: "Switch to Traditional Chinese"
    },
    "zh-TW": {
      title: "GhostMark — Claude Code 圖片標記工具",
      skip: "跳到主要內容",
      primaryNav: "主要導覽",
      navSetup: "設定",
      navSource: "原始碼",
      kicker: "Claude Code 的 macOS 標記工具",
      headline: "先畫清楚，<br>再交給<br>Claude。",
      lede: "在終端機貼上圖片，GhostMark 會先開啟精簡的標記視窗；畫好後，再把圖片送回 Claude Code。",
      download: "下載 GhostMark",
      viewSource: "查看原始碼",
      latestRelease: "最新版本",
      notarized: "Apple 已公證",
      preparing: "正在準備已簽署的安裝程式",
      editorPreview: "GhostMark 在 Claude Code 前開啟、標記圖片並送回終端機的動畫示意",
      done: "完成",
      paste: "貼上",
      mark: "標記",
      send: "送出",
      setupLabel: "設定",
      setupTitle: "安裝一次，<br>照常使用終端機。",
      stepOne: "開啟已簽署的 <strong>.pkg</strong> 安裝程式。",
      stepTwo: "依提示允許「輔助使用」權限。",
      stepThree: "在 Claude Code 執行時貼上圖片。",
      productDetails: "產品資訊",
      worksLabel: "常用終端機都支援",
      worksText: "支援 Ghostty、終端機、iTerm2、Warp 與 IDE 內建終端機。",
      privacyLabel: "隱私優先",
      privacyText: "圖片只留在你的 Mac。不需帳號，不含分析，也不上傳。",
      openSource: "採用開源",
      privacyLink: "隱私權",
      switchLanguage: "Switch to English"
    }
  };

  const hostOwner = location.hostname.endsWith(".github.io")
    ? location.hostname.slice(0, -".github.io".length)
    : "alan890104";
  const pathRepo = location.pathname.split("/").filter(Boolean)[0];
  const repo = pathRepo || "GhostMark";
  const repositoryURL = `https://github.com/${hostOwner}/${repo}`;
  const params = new URLSearchParams(location.search);
  let locale = params.get("lang") === "zh-TW" ? "zh-TW" : "en";
  let releaseTag = null;
  let releasePending = false;

  const applyLocale = () => {
    const strings = copy[locale];
    document.documentElement.lang = locale === "zh-TW" ? "zh-Hant" : "en";
    document.title = strings.title;

    document.querySelectorAll("[data-i18n]").forEach((element) => {
      const key = element.dataset.i18n;
      if (strings[key]) element.textContent = strings[key];
    });
    document.querySelectorAll("[data-i18n-html]").forEach((element) => {
      const key = element.dataset.i18nHtml;
      if (strings[key]) element.innerHTML = strings[key];
    });
    document.querySelectorAll("[data-i18n-aria]").forEach((element) => {
      const key = element.dataset.i18nAria;
      if (strings[key]) element.setAttribute("aria-label", strings[key]);
    });

    const toggle = document.querySelector("[data-language-toggle]");
    toggle.textContent = locale === "en" ? "繁中" : "EN";
    toggle.setAttribute("aria-label", strings.switchLanguage);

    document.querySelectorAll("[data-version]").forEach((label) => {
      label.textContent = releaseTag || strings.latestRelease;
    });

    if (releasePending) {
      document.querySelectorAll("[data-download-label]").forEach((label) => {
        label.textContent = strings.preparing;
      });
    }
  };

  document.querySelectorAll("[data-github-link]").forEach((link) => {
    link.href = repositoryURL;
  });

  document.querySelectorAll("[data-repo-file]").forEach((link) => {
    link.href = `${repositoryURL}/blob/main/${link.dataset.repoFile}`;
  });

  document.querySelector("[data-language-toggle]").addEventListener("click", () => {
    locale = locale === "en" ? "zh-TW" : "en";
    const nextURL = new URL(location.href);
    if (locale === "zh-TW") nextURL.searchParams.set("lang", "zh-TW");
    else nextURL.searchParams.delete("lang");
    history.replaceState(null, "", nextURL);
    applyLocale();
  });

  applyLocale();

  const downloadLinks = document.querySelectorAll("[data-download-link]");
  fetch(`https://api.github.com/repos/${hostOwner}/${repo}/releases/latest`, {
    headers: { Accept: "application/vnd.github+json" }
  })
    .then((response) => response.ok ? response.json() : Promise.reject())
    .then((release) => {
      releaseTag = release.tag_name;
      releasePending = false;
      const downloadURL = `${repositoryURL}/releases/latest/download/GhostMark.pkg`;
      downloadLinks.forEach((link) => {
        link.href = downloadURL;
        link.removeAttribute("aria-disabled");
      });
      applyLocale();
    })
    .catch(() => {
      releasePending = true;
      downloadLinks.forEach((link) => {
        link.removeAttribute("href");
        link.setAttribute("aria-disabled", "true");
      });
      applyLocale();
    });
})();
