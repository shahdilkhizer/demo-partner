export function toCsv(headers, rows) {
  const escape = (value) => {
    let text = String(value ?? "");
    // Prevent spreadsheet formula execution when exporting user-supplied text.
    if (/^[\s]*[=+@-]/.test(text)) text = `'${text}`;
    return `"${text.replace(/"/g, '""')}"`;
  };
  return [headers, ...rows]
    .map((row) => row.map(escape).join(","))
    .join("\r\n");
}

export function downloadCsv(filename, headers, rows) {
  const url = URL.createObjectURL(
    new Blob(["\uFEFF", toCsv(headers, rows)], { type: "text/plain" })
  );
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  // Allow the browser to consume the object URL before releasing it.
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}