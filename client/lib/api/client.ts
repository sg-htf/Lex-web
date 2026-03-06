import type { ProblemDetails } from "@/lib/types/common";
export class ApiError extends Error {
  constructor(public readonly problem: ProblemDetails, public readonly status: number) {
    super(problem.title ?? "API error");
  }
}
export interface ApiFetchOptions extends RequestInit { params?: Record<string, string | number | boolean | undefined>; body?: unknown; }
export async function apiFetch<T>(url: string, options: ApiFetchOptions = {}): Promise<T> {
  const { params, body, ...rest } = options;
  const fullUrl = params ? `${url}?${new URLSearchParams(Object.entries(params).filter(([,v]) => v !== undefined).map(([k,v]) => [k, String(v)]))}` : url;
  const response = await fetch(fullUrl, { ...rest, headers: { "Content-Type": "application/json", ...rest.headers }, body: body !== undefined ? JSON.stringify(body) : rest.body });
  if (response.status === 204) return undefined as T;
  if (!response.ok) { const p = await response.json().catch(() => ({ title: "Unknown error", status: response.status })) as ProblemDetails; throw new ApiError(p, response.status); }
  return response.json() as Promise<T>;
}
