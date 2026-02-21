/**
 * Landing page library functions.
 * Pure vanilla JS, no dependencies.
 */

// ── Smooth scroll ──────────────────────────────────────────────

export function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach((link) => {
    link.addEventListener("click", (e) => {
      const targetId = link.getAttribute("href");
      if (!targetId || targetId === "#") return;

      const target = document.querySelector(targetId);
      if (!target) return;

      e.preventDefault();
      target.scrollIntoView({ behavior: "smooth", block: "start" });

      // Close mobile menu if open
      const nav = document.getElementById("landing-nav-menu");
      const hamburger = document.querySelector(".landing-nav__hamburger");
      if (nav && nav.classList.contains("landing-nav__links--open")) {
        nav.classList.remove("landing-nav__links--open");
        if (hamburger) hamburger.setAttribute("aria-expanded", "false");
      }
    });
  });
}

// ── Tabs ───────────────────────────────────────────────────────

export function initTabs() {
  document.querySelectorAll('[role="tablist"]').forEach((tablist) => {
    const tabs = tablist.querySelectorAll('[role="tab"]');
    tabs.forEach((tab) => {
      tab.addEventListener("click", () => switchTab(tab, tabs));
    });
  });
}

export function switchTab(selectedTab, allTabs) {
  allTabs.forEach((tab) => {
    const panelId = tab.getAttribute("aria-controls");
    const panel = panelId ? document.getElementById(panelId) : null;
    const isSelected = tab === selectedTab;

    tab.setAttribute("aria-selected", String(isSelected));
    tab.classList.toggle("active", isSelected);

    if (panel) {
      panel.hidden = !isSelected;
    }
  });
}

// ── Mobile menu ────────────────────────────────────────────────

export function initMobileMenu() {
  const hamburger = document.querySelector(".landing-nav__hamburger");
  const nav = document.getElementById("landing-nav-menu");
  if (!hamburger || !nav) return;

  hamburger.addEventListener("click", () => {
    const isOpen = nav.classList.toggle("landing-nav__links--open");
    hamburger.setAttribute("aria-expanded", String(isOpen));
  });
}

// ── Scroll reveal ──────────────────────────────────────────────

export function initScrollReveal() {
  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (prefersReducedMotion) return;

  const windows = document.querySelectorAll(".landing-window--reveal");
  if (!windows.length) return;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("landing-window--visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.1 },
  );

  windows.forEach((win) => observer.observe(win));
}

// ── Desktop icons ──────────────────────────────────────────────

export function initDesktopIcons() {
  // Icons that scroll to sections
  document.querySelectorAll("[data-target]").forEach((icon) => {
    icon.addEventListener("click", () => {
      const target = document.querySelector(icon.dataset.target);
      if (target) target.scrollIntoView({ behavior: "smooth" });
    });
  });

  // Easter egg: README.txt
  document.querySelectorAll('[data-easter-egg="readme"]').forEach((icon) => {
    icon.addEventListener("click", () => togglePopup("readme-popup", true));
  });

  // Easter egg: Trash
  document.querySelectorAll('[data-easter-egg="trash"]').forEach((icon) => {
    icon.addEventListener("click", () => togglePopup("trash-popup", true));
  });

  // Close popup buttons
  document.querySelectorAll(".landing-popup__close").forEach((btn) => {
    btn.addEventListener("click", () => {
      const popup = btn.closest(".landing-popup");
      if (popup) togglePopup(popup.id, false);
    });
  });
}

export function togglePopup(id, show) {
  const popup = document.getElementById(id);
  if (!popup) return;
  popup.hidden = !show;
}

// ── Konami code ────────────────────────────────────────────────

const KONAMI_SEQUENCE = [
  "ArrowUp",
  "ArrowUp",
  "ArrowDown",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
  "ArrowLeft",
  "ArrowRight",
  "b",
  "a",
];

export function createKonamiDetector() {
  let index = 0;

  return function onKeyDown(key) {
    if (key === KONAMI_SEQUENCE[index]) {
      index++;
      if (index === KONAMI_SEQUENCE.length) {
        index = 0;
        return true;
      }
    } else {
      index = key === KONAMI_SEQUENCE[0] ? 1 : 0;
    }
    return false;
  };
}

export function triggerKonamiEasterEgg() {
  const body = document.body;
  body.classList.add("landing-konami-active");
  setTimeout(() => body.classList.remove("landing-konami-active"), 5000);
}

export function initKonamiCode() {
  const detect = createKonamiDetector();
  document.addEventListener("keydown", (e) => {
    if (detect(e.key)) {
      triggerKonamiEasterEgg();
    }
  });
}
