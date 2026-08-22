// App-wide constants for the CRASHX admin dashboard.

/**
 * Base URL used to build public invitation links shown/copied in the
 * Invitations page. This is a placeholder — point it at the real public
 * web/landing domain that serves the `/invite/:token` route once known.
 */
export const INVITE_BASE_URL = 'https://crashx.app/invite';

export function buildInvitationLink(token: string): string {
  return `${INVITE_BASE_URL}/${token}`;
}

/** Currency label used everywhere money is displayed — never real money. */
export const CURRENCY_LABEL = 'FCFA VIRTUELS';
