export function formatDate(timestamp: string): string {
  const date = new Date(timestamp);
  return date.toLocaleDateString("id-ID", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}
