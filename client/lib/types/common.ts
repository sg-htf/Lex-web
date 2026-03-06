export interface ProblemDetails { type?: string; title?: string; status?: number; detail?: string; errors?: Array<{ field: string; message: string }>; }
export interface PagedResult<T> { items: T[]; totalCount: number; pageNumber: number; pageSize: number; hasNextPage: boolean; }
