/**
 * Q2 push relay over Server-Sent Events.
 *
 * The first version emitted socket.io events from the app, but the server
 * only ever relayed `updateLocation` — announcements, replies and
 * completions were never forwarded, so "real-time" never worked between
 * devices. Here one educator or NGO post is fanned out by the server to
 * exactly the people allowed to see it (Q6 partitioning by class).
 */
export class RealtimeHub {
  constructor({ heartbeatMs = 25_000, maxPerUser = 3 } = {}) {
    this.clients = new Set();
    this.maxPerUser = maxPerUser;
    this.timer = setInterval(() => this.heartbeat(), heartbeatMs);
    this.timer.unref();
  }

  get size() {
    return this.clients.size;
  }

  attach(req, res, user, sessionExpiresAt, backlog = []) {
    // Cap open streams per person so one account can't exhaust the server.
    const mine = [...this.clients].filter((c) => c.user.id === user.id);
    if (mine.length >= this.maxPerUser) this.drop(mine[0]);

    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    res.write('retry: 5000\n\n');
    const client = { user, res, expiresAt: sessionExpiresAt };
    this.clients.add(client);
    for (const event of backlog) this.write(client, event);
    req.on('close', () => this.clients.delete(client));
    return client;
  }

  /** Sends to every connected client for whom `canSee(user)` is true. */
  publish(event, canSee) {
    let sent = 0;
    for (const c of this.clients) {
      if (canSee(c.user)) {
        this.write(c, event);
        sent++;
      }
    }
    return sent;
  }

  /** Ends every stream belonging to a session (sign-out or revocation). */
  disconnectUser(userId) {
    for (const c of [...this.clients]) if (c.user.id === userId) this.drop(c);
  }

  write(client, { seq, type, data }) {
    client.res.write(`id: ${seq}\nevent: ${type}\ndata: ${JSON.stringify(data)}\n\n`);
  }

  heartbeat(now = Date.now()) {
    for (const c of [...this.clients]) {
      if (c.expiresAt <= now) this.drop(c);
      else c.res.write(': keep-alive\n\n');
    }
  }

  drop(client) {
    this.clients.delete(client);
    try {
      client.res.end();
    } catch {
      // already closed
    }
  }

  close() {
    clearInterval(this.timer);
    for (const c of [...this.clients]) this.drop(c);
  }
}

/** Who may see an announcement: managers and NGO desks see all; students
 * and educators see broadcasts to everyone and posts to their own class. */
export function canSeeAnnouncement(user, audience) {
  if (user.role === 'manager' || user.role === 'ngo') return true;
  return audience === 'ALL' || user.classCode === audience;
}
