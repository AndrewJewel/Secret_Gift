import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Clave de firma de la app. En local sale de android/key.properties; en
// GitHub Actions, de variables de entorno. Ni la clave ni su contraseña
// entran nunca en el repositorio (es público).
//
// Tiene que ser SIEMPRE la misma: Android no deja actualizar una app firmada
// con otra clave, y los enlaces de invitación solo abren la app si su huella
// SHA-256 está registrada en Firebase. Si se pierde, la app no se puede
// actualizar nunca más en Google Play.
val propiedadesFirma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
}
fun datoFirma(propiedad: String, variable: String): String? =
    propiedadesFirma.getProperty(propiedad) ?: System.getenv(variable)

val almacenFirma = datoFirma("storeFile", "ANDROID_KEYSTORE_PATH")

android {
    namespace = "app.secretgift"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "app.secretgift"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (almacenFirma != null) {
            create("release") {
                storeFile = file(almacenFirma)
                storePassword = datoFirma("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = datoFirma("keyAlias", "ANDROID_KEY_ALIAS") ?: "secretgift"
                keyPassword = datoFirma("keyPassword", "ANDROID_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Sin clave propia a mano, firma con la de debug: un APK sin
            // firmar (falta META-INF/MANIFEST.MF) Android lo rechaza siempre
            // con "no se instaló la app". Sirve para probar, NO para publicar.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            // Le decimos explícitamente que NO intente encoger nada
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
