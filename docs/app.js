(() => {
  const copy = {
    en: {
      title: "GhostMark — Image markup for AI coding agents",
      skip: "Skip to content",
      primaryNav: "Primary navigation",
      navSetup: "Setup",
      navSource: "Source",
      kicker: "A macOS utility for AI coding agents",
      headline: "Mark it.<br>Send it to your<br>AI agent.",
      lede: "Paste an image in Claude Code, Claude Desktop, or Codex. Add freehand marks, straight lines, arrows, or text, then send it straight back to your AI agent.",
      download: "Download GhostMark",
      viewSource: "View source",
      latestRelease: "Latest release",
      notarized: "Apple notarized",
      preparing: "Preparing signed installer",
      editorPreview: "Animated preview of GhostMark opening over Claude Code, marking an image, and sending it back",
      demoPrompt: "Explain the highlighted issue",
      demoConversationPrompt: "Review this screenshot and explain the issue",
      demoConversationReply: "I’ll inspect the area you marked.",
      demoThinking: "Considering…",
      pastingImage: "pasting image",
      cancel: "Cancel",
      editorTitle: "Mark up before sending to your AI agent",
      sendToClaude: "Send to Claude Code",
      stepPaste: "Paste in Claude Code",
      stepFocus: "GhostMark takes focus",
      stepMark: "Mark the image",
      stepSend: "Press Enter to send",
      stepAttached: "Image attached",
      setupLabel: "Setup",
      setupTitle: "Install once.<br>Use the apps you already know.",
      stepOne: "Open the signed <strong>.pkg</strong> installer.",
      stepTwo: "Allow Accessibility access when GhostMark asks.",
      stepThree: "Paste an image in Claude Code, Claude, or Codex.",
      productDetails: "Product details",
      worksLabel: "Works where you work",
      worksText: "Claude, Codex, Ghostty, Terminal, iTerm2, Warp, and embedded terminals.",
      privacyLabel: "Private by design",
      privacyText: "Your images stay on your Mac. No account, analytics, or uploads.",
      openSource: "Open source under the",
      licenseLink: "MIT License",
      privacyLink: "Privacy",
      switchLanguage: "Switch to Traditional Chinese"
    },
    "zh-TW": {
      title: "GhostMark — AI Agent 圖片標記工具",
      skip: "跳到主要內容",
      primaryNav: "主要導覽",
      navSetup: "使用方式",
      navSource: "原始碼",
      kicker: "給 AI Agent 使用的圖片標記工具",
      headline: "標記圖片，<br>再送給你的<br>AI Agent。",
      lede: "在 Claude Code、Claude 或 Codex 貼上圖片後，用畫筆、直線、箭頭或文字直接標出想法，再把完成的圖片送回 AI Agent。",
      download: "下載 GhostMark",
      viewSource: "查看原始碼",
      latestRelease: "最新版本",
      notarized: "通過 Apple 公證",
      preparing: "正在準備安裝檔",
      editorPreview: "在 Claude Code 貼上圖片後，GhostMark 跳出標記視窗並將完成圖片送回終端機的動畫示意",
      demoPrompt: "說明我標出的問題",
      demoConversationPrompt: "請看這張截圖，說明問題出在哪裡",
      demoConversationReply: "我會檢查你標出的區域。",
      demoThinking: "正在思考…",
      pastingImage: "正在貼上圖片",
      cancel: "取消",
      editorTitle: "標記完成後，送給你的 AI Agent",
      sendToClaude: "送到 Claude Code",
      stepPaste: "在 Claude Code 貼上圖片",
      stepFocus: "GhostMark 取得焦點",
      stepMark: "標記圖片",
      stepSend: "按 Enter 送回 Claude Code",
      stepAttached: "圖片已加入輸入框",
      setupLabel: "開始使用",
      setupTitle: "裝好之後，<br>照平常的方式貼上圖片就好。",
      stepOne: "打開已簽署的 <strong>.pkg</strong> 安裝檔。",
      stepTwo: "依照提示開啟「輔助使用」權限。",
      stepThree: "在 Claude Code、Claude 或 Codex 直接貼上圖片。",
      productDetails: "產品資訊",
      worksLabel: "在熟悉的地方使用",
      worksText: "支援 Claude、Codex、Ghostty、終端機、iTerm2、Warp 和 IDE 內建終端機。",
      privacyLabel: "圖片只留在本機",
      privacyText: "不用登入、不做追蹤，也不會把圖片上傳到任何地方。",
      openSource: "採用",
      licenseLink: "MIT License 開源",
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

  const demo = document.querySelector("[data-demo]");
  const demoCaption = document.querySelector("[data-demo-caption]");
  const demoStep = document.querySelector("[data-demo-step]");
  const demoProgress = document.querySelector("[data-demo-progress]");
  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const demoDuration = 4.3;
  const demoPhases = [
    { at: 0, phase: "ready", step: "01", caption: "stepPaste" },
    { at: 0.22, phase: "paste", step: "01", caption: "stepPaste" },
    { at: 0.48, phase: "opening", step: "02", caption: "stepFocus" },
    { at: 0.7, phase: "focused", step: "02", caption: "stepFocus" },
    { at: 0.86, phase: "drawing", step: "03", caption: "stepMark" },
    { at: 1.78, phase: "reviewing", step: "03", caption: "stepMark" },
    { at: 1.9, phase: "enter-hint", step: "04", caption: "stepSend" },
    { at: 2.3, phase: "enter-press", step: "04", caption: "stepSend" },
    { at: 2.5, phase: "returning", step: "04", caption: "stepSend" },
    { at: 2.72, phase: "attached", step: "05", caption: "stepAttached" },
    { at: 4.02, phase: "reset", step: "05", caption: "stepAttached" }
  ];
  const requestedDemoPhase = params.get("demo");

  const renderDemoPhase = (next) => {
    if (!demo || demo.dataset.phase === next.phase) return;
    demo.dataset.phase = next.phase;
    demoStep.textContent = next.step;
    demoCaption.dataset.i18n = next.caption;
    demoCaption.textContent = copy[locale][next.caption];
  };

  if (demo) {
    const fixedPhase = demoPhases.find((item) => item.phase === requestedDemoPhase);
    if (fixedPhase) {
      renderDemoPhase(fixedPhase);
      demoProgress.style.transform = `scaleX(${fixedPhase.at / demoDuration})`;
    } else if (reducedMotion) {
      renderDemoPhase({ phase: "drawing", step: "03", caption: "stepMark" });
      demoProgress.style.transform = "scaleX(.58)";
    } else {
      let startedAt;
      const tickDemo = (now) => {
        startedAt ??= now;
        const elapsed = ((now - startedAt) / 1000) % demoDuration;
        const next = demoPhases.findLast((item) => elapsed >= item.at) ?? demoPhases[0];
        renderDemoPhase(next);
        demoProgress.style.transform = `scaleX(${elapsed / demoDuration})`;
        requestAnimationFrame(tickDemo);
      };
      requestAnimationFrame(tickDemo);
    }
  }

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
