buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Necessário para o Firebase
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Lógica de build do Flutter simplificada para evitar erros de sintaxe Kotlin
rootProject.layout.buildDirectory.set(file("${rootProject.projectDir}/../build"))

subprojects {
    project.layout.buildDirectory.set(file("${rootProject.layout.buildDirectory.get()}/${project.name}"))
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}