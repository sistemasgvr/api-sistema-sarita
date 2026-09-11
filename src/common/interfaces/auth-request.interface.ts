import type { Request } from 'express';
import type { AuthenticatedUser } from './authenticated-user.interface';

export type AuthRequest = Request & { user: AuthenticatedUser };
