plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jchd.closi_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.jchd.closi_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // VTM — OpenGL vector map (reemplaza MapsForge)
    implementation("org.mapsforge:vtm-android:0.25.0:natives-armeabi-v7a")
    implementation("org.mapsforge:vtm-android:0.25.0:natives-arm64-v8a")
    implementation("org.mapsforge:vtm-android:0.25.0:natives-x86")
    implementation("org.mapsforge:vtm-android:0.25.0:natives-x86_64")
    implementation("org.mapsforge:vtm-android:0.25.0")
    // SVG icons para los temas VTM
    implementation("com.caverock:androidsvg:1.4")
}

flutter {
    source = "../.."
}