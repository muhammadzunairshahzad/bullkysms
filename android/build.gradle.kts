allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    val subproject = this

    plugins.withId("com.android.library") {
        subproject.extensions.configure<com.android.build.api.dsl.LibraryExtension> {
            if (namespace == null) {
                namespace = "au.com.bullkysms.${subproject.name.replace("-", "_")}"
            }
        }
    }

    plugins.withId("com.android.application") {
        subproject.extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
            if (namespace == null) {
                namespace = "au.com.bullkysms.${subproject.name.replace("-", "_")}"
            }
        }
    }

    subproject.afterEvaluate {
        plugins.withId("com.android.library") {
            subproject.extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                compileSdk = 36
            }
        }
        plugins.withId("com.android.application") {
            subproject.extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
                compileSdk = 36
            }
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    project.tasks.withType<com.android.build.gradle.tasks.ProcessLibraryManifest>().configureEach {
        doFirst {
            val manifestFile = file("${subproject.projectDir}/src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val content = manifestFile.readText()
                if (content.contains("package=")) {
                    val updatedContent = content.replace(Regex("""\s*package="[^"]*""""), "")
                    manifestFile.writeText(updatedContent)
                    println("SUCCESS: Stripped package attribute from ${subproject.name} manifest.")
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
