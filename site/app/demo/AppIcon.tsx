/** The app icon, from Design/Icon/appicon-small.svg: the terminal squircle, the prompt, the cursor. */
export function AppIcon({ size = 64, className = "" }: { size?: number; className?: string }) {
  return (
    <svg viewBox="100 100 824 824" width={size} height={size} className={className} aria-hidden="true">
      <rect x="100" y="100" width="824" height="824" rx="186" fill="#111216" />
      <rect x="170" y="270" width="684" height="560" rx="100" fill="#3a3d47" />
      <polygon points="432,280 512,180 592,280" fill="#3a3d47" />
      <polyline points="290,410 430,550 290,690" fill="none" stroke="#fff" strokeWidth="104" strokeLinecap="round" strokeLinejoin="round" />
      <rect x="530" y="450" width="200" height="200" rx="40" fill="#3bc28a" />
    </svg>
  );
}

/** The mono mark from Design/Icon/mark-mono.svg: strokes in the text colour, the cursor green. */
export function Mark({ size = 16, className = "" }: { size?: number; className?: string }) {
  return (
    <svg viewBox="0 0 18 18" width={size} height={size} className={`mark ${className}`.trim()} aria-hidden="true">
      <rect x="1.75" y="4.75" width="14.5" height="11.5" rx="2.4" fill="none" stroke="currentColor" strokeWidth="1.5" />
      <polygon points="6.8,5 9,2.4 11.2,5" fill="currentColor" />
      <polyline points="5,8.4 7.4,10.5 5,12.6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
      <rect x="9.4" y="9" width="3.2" height="3.2" rx=".7" className="mark-cursor" />
    </svg>
  );
}
