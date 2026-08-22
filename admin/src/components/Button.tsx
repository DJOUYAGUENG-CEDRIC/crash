import type { ButtonHTMLAttributes } from 'react';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger';

const VARIANT_CLASSES: Record<Variant, string> = {
  primary: 'bg-violet-600 text-white hover:bg-violet-500 focus-visible:outline-violet-500',
  secondary:
    'bg-zinc-800 text-zinc-100 hover:bg-zinc-700 ring-1 ring-inset ring-zinc-700 focus-visible:outline-zinc-500',
  ghost: 'bg-transparent text-zinc-400 hover:bg-zinc-800 hover:text-zinc-100',
  danger: 'bg-red-600 text-white hover:bg-red-500 focus-visible:outline-red-500',
};

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
}

export function Button({ variant = 'secondary', className = '', ...rest }: ButtonProps) {
  return (
    <button
      type="button"
      className={`inline-flex items-center justify-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:cursor-not-allowed disabled:opacity-50 ${VARIANT_CLASSES[variant]} ${className}`}
      {...rest}
    />
  );
}
