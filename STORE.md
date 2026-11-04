# Публикация SATL в магазинах

## 1. Подпись Android (обязательно для Google Play)

Создайте ключ (один раз, храните файл и пароли — восстановить нельзя):

```bash
keytool -genkey -v -keystore satl-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Создайте `android/key.properties`:

```
storePassword=ВАШ_ПАРОЛЬ_ХРАНИЛИЩА
keyPassword=ВАШ_ПАРОЛЬ_КЛЮЧА
keyAlias=upload
storeFile=../../satl-upload.jks
```

В `android/app/build.gradle.kts` добавьте чтение этого файла и `signingConfigs`.
Пример (Kotlin DSL):

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

Сборка для магазина:

```bash
flutter build appbundle --release
```

Файл: `build/app/outputs/bundle/release/app-release.aab`.

## 2. Google Play

1. Аккаунт разработчика: https://play.google.com/console (25 $ разово).
2. Создать приложение, название SATL, категория «Дом».
3. Загрузить `.aab`, заполнить описание, скриншоты (минимум 2), иконку 512×512.
4. Пройти «Заполнение карточки приложения»: политика конфиденциальности,
   рейтинг, целевая аудитория, безопасность данных.
5. Отправить на проверку. Первая проверка обычно 1–7 дней.

Политику конфиденциальности можно разместить на любом своём домене —
например, `https://satl.app/privacy`. В ней укажите: приложение хранит адрес
сервера и токен доступа локально на устройстве и не передаёт их третьим лицам.

## 3. App Store

Нужны: Mac, Xcode, аккаунт Apple Developer (99 $ в год).

```bash
flutter build ipa --release
```

Далее через Xcode Organizer или Transporter загрузить сборку в App Store Connect,
добавить её в TestFlight, проверить и отправить на ревью.
Понадобятся те же материалы: описание, скриншоты (6.7" и 6.1"), политика
конфиденциальности, возрастной рейтинг.

## 4. Что стоит доработать перед публикацией

- Заменить `shared_preferences` на `flutter_secure_storage` для токенов.
- Добавить экран политики конфиденциальности внутри приложения.
- Локализовать интерфейс (сейчас русский).
- Проверить работу на планшетах и в ландшафтной ориентации.
- Добавить обработку самоподписанных сертификатов (сейчас HTTPS должен быть валидным).
