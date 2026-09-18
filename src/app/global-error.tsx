"use client";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html>
      <body className="flex min-h-screen flex-col items-center justify-center p-4 font-sans antialiased">
        <div className="max-w-md text-center">
          <h2 className="text-xl font-bold mb-2">Something went wrong</h2>
          <p className="text-sm text-gray-500 mb-4">
            An unexpected error occurred.
          </p>
          <button
            onClick={() => reset()}
            className="rounded bg-black px-4 py-2 text-sm text-white hover:bg-black/80"
          >
            Try again
          </button>
        </div>
      </body>
    </html>
  );
}
