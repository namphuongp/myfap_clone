const terms = {
  SPRING: { month: 0, label: "Spring" },
  SUMMER: { month: 4, label: "Summer" },
  FALL: { month: 8, label: "Fall" },
};
export function semesterData(term, year) {
  if (!terms[term] || !Number.isInteger(year) || year < 2000 || year > 2100)
    throw new Error("Học kỳ không hợp lệ");
  const { month, label } = terms[term];
  const academicYear = term === "FALL" ? year : year - 1;
  return {
    code: `${term}-${year}`,
    name: `${label} ${year}`,
    term,
    year,
    academic_year: `${academicYear}-${academicYear + 1}`,
    start_at: new Date(Date.UTC(year, month, 1) - 7 * 3600000),
    end_at: new Date(Date.UTC(year, month + 3, 1) - 7 * 3600000),
    legacy: false,
  };
}
export function currentTerm(now = new Date()) {
  const local = new Date(now.getTime() + 7 * 3600000);
  const year = local.getUTCFullYear();
  return (
    Object.keys(terms)
      .map((term) => semesterData(term, year))
      .find((s) => s.start_at <= now && s.end_at > now) ?? null
  );
}
export function nextTerm(now = new Date()) {
  const year = new Date(now.getTime() + 7 * 3600000).getUTCFullYear();
  return [year, year + 1]
    .flatMap((y) => Object.keys(terms).map((t) => semesterData(t, y)))
    .filter((s) => s.start_at > now)
    .sort((a, b) => a.start_at - b.start_at)[0];
}
