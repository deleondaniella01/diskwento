buildscript {
    // Define the kotlin_version using the 'extra' property if needed,
    // though often it's already defined elsewhere or not strictly required here if using Flutter's default
    // val kotlin_version by extra("1.9.0") // Example, adjust if your actual Kotlin version differs

    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin
        classpath("com.android.tools.build:gradle:8.8.0") // Or your current Android Gradle Plugin version
        // Kotlin Gradle Plugin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0") // Use a specific version, or val kotlin_version
        // Google Services Plugin for Firebase
        classpath("com.google.gms:google-services:4.4.2") // THIS IS THE CRUCIAL LINE for Firebase
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// These lines are from your original .kts file, ensure they are outside buildscript
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}