export interface HealthReport {
  readonly status: "ok";
  readonly service: string;
  readonly version: string;
}

export function buildHealthReport(service: string, version: string): HealthReport {
  return { status: "ok", service, version };
}
