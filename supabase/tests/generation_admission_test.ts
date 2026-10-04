import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  admissionErrorDetails,
  admissionHttpStatus,
  admissionPublicCode,
  admissionPublicMessage,
  requestGenerationAdmission,
  type RpcCaller,
} from "../functions/_shared/generation_admission.ts";
import { createCostQuote } from "../functions/_shared/cost_policy.ts";

const USER_ID = "5a9b8d4c-6e2f-4c7a-9b1d-2e3f4a5b6c7d";
const REQUEST_ID = "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0";

type MeteringRpcClient = RpcCaller & {
  calls: Array<{ name: string; args: Record<string, unknown> }>;
};

function rpcClient(
  handler: (name: string, args: Record<string, unknown>) => unknown,
): MeteringRpcClient {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  return {
    calls,
    rpc(name: string, args: Record<string, unknown>) {
      calls.push({ name, args });
      const value = handler(name, args);
      if (value instanceof Error) throw value;
      return Promise.resolve({ data: value, error: null });
    },
  };
}

Deno.test("metering continues without enforcement when limits are off", async () => {
  const client = rpcClient((name) => {
    if (name === "record_generation_usage") {
      return { reservationId: "usage-1", enforced: false };
    }
    throw new Error("enforcement RPC must not run while limits are off");
  });
  const result = await requestGenerationAdmission(client, {
    userId: USER_ID,
    clientRequestId: REQUEST_ID,
    feature: "sentence",
    units: { itemCount: 1 },
    payloadHash: "hash",
    enforcementEnabled: false,
  });

  assertEquals(result.allowed, true);
  assertEquals(result.reservationId, "usage-1");
  assertEquals(client.calls.map((call) => call.name), [
    "record_generation_usage",
  ]);
});

Deno.test("a metering ledger failure fails closed even with limits off", async () => {
  const client = rpcClient(() => {
    throw new Error("ledger unavailable");
  });
  const result = await requestGenerationAdmission(client, {
    userId: USER_ID,
    clientRequestId: REQUEST_ID,
    feature: "sentence",
    units: { itemCount: 1 },
    payloadHash: "hash",
    enforcementEnabled: false,
  });

  assertEquals(result.allowed, false);
  assertEquals(result.errorCode, "service_budget_protected");
});

Deno.test("the public-mode recorder enforces the daily platform allowance", async () => {
  const client = {
    calls: [] as Array<{ name: string; args: Record<string, unknown> }>,
    rpc(name: string, args: Record<string, unknown>) {
      this.calls.push({ name, args });
      return Promise.resolve({
        data: null,
        error: { message: "platform_daily_budget_exhausted" },
      });
    },
  };
  const result = await requestGenerationAdmission(client, {
    userId: USER_ID,
    clientRequestId: REQUEST_ID,
    feature: "sentence",
    units: { itemCount: 1 },
    payloadHash: "hash",
    enforcementEnabled: false,
  });

  assertEquals(result.allowed, false);
  assertEquals(result.errorCode, "service_budget_protected");
  assertEquals(result.internalReason, "daily_limit_reached");
  assertEquals(admissionHttpStatus(result), 503);
  assertEquals(
    admissionPublicCode(result),
    "generation_temporarily_unavailable",
  );
  assertEquals(
    admissionPublicMessage(result),
    "Generation is temporarily unavailable",
  );
  const publicDetails = admissionErrorDetails(result, {
    feature: "sentence",
    clientRequestId: REQUEST_ID,
  });
  assertEquals("internalReason" in publicDetails, false);
  assertEquals("resetsAt" in publicDetails, true);
});

Deno.test("enforcement reserves against the membership allowance", async () => {
  const quote = createCostQuote("sentence", { itemCount: 1 });
  const client = rpcClient((name) => {
    if (name === "reserve_generation_allowance") {
      return { reservationId: "reservation-1" };
    }
    throw new Error("unexpected RPC: " + name);
  });
  const result = await requestGenerationAdmission(client, {
    userId: USER_ID,
    clientRequestId: REQUEST_ID,
    feature: "sentence",
    units: { itemCount: 1 },
    payloadHash: "hash",
    enforcementEnabled: true,
    quote,
  });

  assertEquals(result.allowed, true);
  assertEquals(result.reservationId, "reservation-1");
  assertEquals(client.calls.length, 1);
  assertEquals(client.calls[0].name, "reserve_generation_allowance");
});
