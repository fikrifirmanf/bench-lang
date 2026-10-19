import Image from "next/image";

import { langLogo, langMonogram } from "@/lib/catalog";

const SIZES = {
  sm: { box: "size-8 rounded-lg", img: 18, text: "text-[11px]" },
  md: { box: "size-10 rounded-[10px]", img: 24, text: "text-[13px]" },
  lg: { box: "size-20 rounded-[18px]", img: 52, text: "text-2xl" },
} as const;

interface Props {
  slug: string;
  size?: keyof typeof SIZES;
  bordered?: boolean;
}

/** Decorative: always rendered next to the language's name, so it carries no alt text. */
export function LangIcon({ slug, size = "md", bordered = true }: Props) {
  const s = SIZES[size];
  const logo = langLogo(slug);
  return (
    <span
      aria-hidden="true"
      className={`inline-flex shrink-0 items-center justify-center bg-card ${s.box} ${bordered ? "border-2 border-ink" : ""}`}
    >
      {logo ? (
        <Image src={logo} alt="" width={s.img} height={s.img} />
      ) : (
        <span className={`font-mono font-bold leading-none ${s.text}`}>{langMonogram(slug)}</span>
      )}
    </span>
  );
}
