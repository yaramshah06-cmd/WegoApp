const express = require("express");
const http = require("http");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: "*" },
});

const users = {};
const activeCalls = {};

// Random match queue
let waitingUser = null;

io.on("connection", (socket) => {
  console.log("User connected:", socket.id);

  socket.on("register", (userId) => {
    users[userId] = socket.id;
    socket.userId = userId;
    socket.emit("registered", { userId, socketId: socket.id });
  });

  socket.on("find_match", () => {
    if (waitingUser && waitingUser.id !== socket.id) {
      const partner = waitingUser;
      waitingUser = null;
      socket.emit("match_found", { matchedUserId: partner.userId });
      partner.emit("match_found", { matchedUserId: socket.userId });
    } else {
      waitingUser = socket;
      socket.emit("waiting_for_match");
    }
  });

  socket.on("cancel_match", () => {
    if (waitingUser && waitingUser.id === socket.id) {
      waitingUser = null;
      socket.emit("match_cancelled");
    }
  });

  socket.on("call-user", ({ calleeId, callerId, callType, offer }) => {
    const calleeSocket = users[calleeId];
    if (!calleeSocket) {
      socket.emit("call-failed", { reason: "User not available" });
      return;
    }
    const callId = `${callerId}-${calleeId}-${Date.now()}`;
    activeCalls[callId] = { caller: callerId, callee: calleeId, type: callType };
    io.to(calleeSocket).emit("incoming-call", { callId, callerId, callType, offer });
    socket.emit("call-initiated", { callId });
  });

  socket.on("answer-call", ({ callId, callerId, answer }) => {
    const callerSocket = users[callerId];
    if (callerSocket) {
      io.to(callerSocket).emit("call-answered", { callId, answer });
    }
  });

  socket.on("ice-candidate", ({ targetId, candidate }) => {
    const targetSocket = users[targetId];
    if (targetSocket) {
      io.to(targetSocket).emit("ice-candidate", { candidate, fromId: socket.userId });
    }
  });

  socket.on("reject-call", ({ callId, callerId }) => {
    const callerSocket = users[callerId];
    if (callerSocket) io.to(callerSocket).emit("call-rejected", { callId });
    delete activeCalls[callId];
  });

  socket.on("end-call", ({ callId, targetId }) => {
    const targetSocket = users[targetId];
    if (targetSocket) io.to(targetSocket).emit("call-ended", { callId });
    delete activeCalls[callId];
  });

  socket.on("heart-pressed", ({ fromUserId, toUserId }) => {
    const toSocket = users[toUserId];
    if (toSocket) io.to(toSocket).emit("match-heart", { fromUserId });
  });

  socket.on("cross-pressed", ({ fromUserId, toUserId }) => {
    const toSocket = users[toUserId];
    if (toSocket) io.to(toSocket).emit("profile-removed", { removedBy: fromUserId });
  });

  socket.on("disconnect", () => {
    if (socket.userId) delete users[socket.userId];
    if (waitingUser && waitingUser.id === socket.id) waitingUser = null;
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`✅ Signaling server running on port ${PORT}`);
});