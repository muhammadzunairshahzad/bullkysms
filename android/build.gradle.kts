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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// Replace your existing subprojects namespace block with this:

subprojects {
    val subproject = this

    // 1. Force the namespace for the subproject
    plugins.withType<com.android.build.gradle.api.AndroidBasePlugin> {
        subproject.extensions.configure<com.android.build.gradle.BaseExtension> {
            if (namespace == null) {
                namespace = "app.com.bullkysms.${subproject.name.replace("-", "_")}"
            }
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