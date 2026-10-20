import type { Metadata } from "next";
import { JetBrains_Mono, Space_Grotesk } from "next/font/google";

import { SiteHeader } from "@/components/SiteHeader";

import "./globals.css";

const sans = Space_Grotesk({ subsets: ["latin"], variable: "--font-space-grotesk", display: "swap" });
const mono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-jetbrains-mono", display: "swap" });

export const metadata: Metadata = {
  title: { default: "bench/lang: programming language benchmarks", template: "%s · bench/lang" },
  description: "Compare 28 languages, compilers and runtimes on the same machine, in the same run.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sans.variable} ${mono.variable}`}>
      <body className="min-h-screen bg-paper font-sans text-[17px] leading-normal text-ink antialiased">
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:absolute focus:top-3 focus:left-3 focus:z-10 focus:rounded-lg focus:border-2 focus:border-ink focus:bg-lemon focus:px-3 focus:py-2"
        >
          Skip to content
        </a>
        <SiteHeader />
        <main id="main" className="mx-auto max-w-[1240px] px-4 pb-16 sm:px-6">
          {children}
        </main>
        <footer className="mx-auto flex max-w-[1240px] flex-wrap justify-between gap-3 px-4 pb-12 text-[15px] text-ink-soft sm:px-6">
          <span>
            Logos from Devicon.
          </span>
          <span>
            Built and maintained by{" "}
            <a className="font-semibold underline" href="https://fikrifirmanf.com">
              Fikri Firman Fadilah
            </a>
          </span>
        </footer>
      </body>
    </html>
  );
}
