importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyB-74LEOSvZAl9pgtOvLgY0bOYwlHIBmSE",
  authDomain: "eniza-hypermarket.firebaseapp.com",
  databaseURL: "",
  projectId: "eniza-hypermarket",
  storageBucket: "eniza-hypermarket.appspot.com",
  messagingSenderId: "987650730174",
  appId: "1:987650730174:web:92a2dcb9e1e880a26996ef",
  measurementId: "G-PD78193EJT"
});

const messaging = firebase.messaging();

messaging.setBackgroundMessageHandler(function (payload) {
    const promiseChain = clients
        .matchAll({
            type: "window",
            includeUncontrolled: true
        })
        .then(windowClients => {
            for (let i = 0; i < windowClients.length; i++) {
                const windowClient = windowClients[i];
                windowClient.postMessage(payload);
            }
        })
        .then(() => {
            const title = payload.notification.title;
            const options = {
                body: payload.notification.score
              };
            return registration.showNotification(title, options);
        });
    return promiseChain;
});
self.addEventListener('notificationclick', function (event) {
    console.log('notification received: ', event)
});