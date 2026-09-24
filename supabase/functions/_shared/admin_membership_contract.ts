// Admin membership management and operations contract.

export type AdminMembershipActionType =
  | "grant_membership"
  | "compensate_membership"
  | "revoke_grant"
  | "replay_order"
  | "record_manual_payment"
  | "toggle_generation_service";

export interface AdminUserListItem {
  userId: string;
  emailMasked: string;
  plan: string;
  status: string;
  expiresAt: string | null;
  serviceStatus: "active" | "paused";
  createdAt: string;
}

export interface AdminMembershipActionRequest {
  action: AdminMembershipActionType;
  targetUserId: string;
  plan?: "monthly" | "pro";
  months?: number;
  reason: string;
  clientRequestId: string;
  orderId?: string;
  membershipId?: string;
  channel?: string;
  transactionId?: string;
  amountFenCny?: number;
}

export function maskEmail(email: string): string {
  const atIndex = email.indexOf("@");
  if (atIndex <= 1) return email;
  const name = email.slice(0, atIndex);
  const domain = email.slice(atIndex);
  if (name.length <= 2) return `${name[0]}*${domain}`;
  return `${name[0]}${"*".repeat(name.length - 2)}${
    name[name.length - 1]
  }${domain}`;
}
