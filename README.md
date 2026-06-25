# Zahter Kıraathane - WebRTC & Firebase Sesli ve Yazılı Sohbet

Zahter Kıraathane; Flutter, Firebase ve WebRTC teknolojilerini bir araya getirerek gerçek zamanlı, düşük gecikmeli sesli iletişim ve yazılı (fısıltı dahil) sohbet odaları sunan bir mobil uygulamadır. 

---

## Proje Özellikleri

* **Gerçek Zamanlı P2P Ses:** `flutter_webrtc` kütüphanesi kullanılarak sunucusuz, doğrudan cihazlar arası ses iletimi sağlanır.
* **Sinyalleşme ve Oda Yönetimi:** Firebase Firestore üzerinden odalar koordine edilir ve katılımcı takibi dinamik olarak gerçekleştirilir.
* **Akıllı Heartbeat Sistemi:** Bağlantısı kopan ya da uygulamayı aniden kapatan kullanıcıları otomatik olarak odadan temizleyen arka plan mekanizması bulunur.
* **Konuşma Algılama (Audio Level Monitoring):** WebRTC istatistikleri taranarak o an kimin konuştuğu arayüzde dinamik olarak gösterilir.
* **Gelişmiş Yazılı Sohbet ve Fısıldama:** Genel mesajlaşmanın yanı sıra, sadece hedeflenen kullanıcıya özel gizli (fısıltı) mesaj gönderilebilir.
* **Kullanıcı Kontrolleri:** Mikrofon kapatma (Mute), kulaklık kapatma (Deaf) ve odadaki diğer kullanıcıları yerel olarak susturabilme imkanı sunulur.
* **Karanlık ve Aydınlık Tema Desteği:** Kullanıcı tercihine göre yerel hafızaya kaydedilen tema yönetimi mevcuttur.

---

## ⚠️ Önemli Yapılandırma Adımı

Uygulamayı kendi Firebase projenizle sorunsuz bir şekilde çalıştırabilmek için **kendi API anahtarlarınızı, kimliklerinizi (ID) ve proje yapılandırmalarınızı** tanımlamanız gerekmektedir. 

Bunun için aşağıdaki üç dosyayı kendi projenizin bilgileriyle düzenlemeli veya değiştirmelisiniz:

1. **Kök Dizindeki `firebase.json` Dosyası:** Firebase CLI araçlarının ve Web platformunun projenizle eşleşmesi için bu dosyayı güncelleyin.
2. **`lib/firebase_options.dart` Dosyası:** Firebase projenizi oluşturduktan sonra `flutterfire configure` komutuyla veya Firebase Konsolundan aldığınız platform bazlı yapılandırma değerleriyle bu dosyayı güncelleyin.
3. **`android/app/google-services.json` Dosyası:** Firebase Konsolunda Android uygulamanızı tanımladıktan sonra indirdiğiniz yapılandırma dosyasını bu hedef dizine yerleştirin.

---

## Kurulum ve Çalıştırma

### 1. İzinlerin Yapılandırılması

Uygulamanın sesli sohbet özelliğini kullanabilmesi için mikrofon izinlerinin tanımlanmış olması gerekmektedir.

* **Android (`android/app/src/main/AndroidManifest.xml`):**
  ```xml
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
  <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
