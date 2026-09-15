import type { VendorCost } from "../admin-cost-sync/index.ts";

export async function fetchOpenAiDailyCosts(
  input: {
    adminKey: string;
    projectId: string;
    start: string;
    end: string;
  },
  dependencies: { fetch?: typeof fetch } = {},
): Promise<{ data: VendorCost[] }> {
  const url = new URL("https://api.openai.com/v1/organization/costs");
  const fetchImpl = dependencies.fetch ?? fetch;
  url.searchParams.set(
    "start_time",
    Math.floor(Date.parse(input.start) / 1000).toString(),
  );
  url.searchParams.set(
    "end_time",
    Math.floor(Date.parse(input.end) / 1000).toString(),
  );
  url.searchParams.set("bucket_width", "1d");
  url.searchParams.set("project_ids[]", input.projectId);

  const response = await fetchImpl(url, {
    headers: {
      Authorization: `Bearer ${input.adminKey}`,
      "Content-Type": "application/json",
    },
  });
  if (!response.ok) throw new Error("openai_costs_unavailable");
  const body = await response.json() as {
    data?: Array<{
      start_time?: number;
      results?: Array<{ amount?: { value?: number; currency?: string } }>;
    }>;
  };
  const rows: VendorCost[] = [];
  for (const bucket of body.data ?? []) {
    if (typeof bucket.start_time !== "number") continue;
    for (const result of bucket.results ?? []) {
      const amount = result.amount?.value;
      if (typeof amount !== "number" || amount < 0) continue;
      rows.push({
        date: new Date(bucket.start_time * 1000).toISOString().slice(0, 10),
        lineItem: "openai",
        amount,
        currency: result.amount?.currency ?? "USD",
        projectId: input.projectId,
      });
    }
  }
  return { data: rows };
}
