importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyARM09F0FUHQSUi1PMezEerveHK3RHShMQ",
  authDomain: "stepz-call.firebaseapp.com",
  projectId: "stepz-call",
  storageBucket: "stepz-call.firebasestorage.app",
  messagingSenderId: "800980554425",
  appId: "1:800980554425:web:08be0780abe4377171c168"
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage(function(payload) {
  const title = (payload.notification && payload.notification.title) || (payload.data && payload.data.title) || "Stepz Call";
  const body = (payload.notification && payload.notification.body) || (payload.data && payload.data.body) || "";
  self.registration.showNotification(title, { body: body, data: payload.data || {} });
});
