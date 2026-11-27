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
// Paksa compileSdk = 36 untuk semua subproyek plugin Flutter.
// Harus didaftarkan sebelum evaluationDependsOn(":app") dan memakai afterEvaluate
// agar menimpa nilai compileSdk lama di build.gradle masing-masing plugin.
subprojects {
    if (project.name != "app") {
        val applyCompileSdk = Action<Project> {
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                compileSdkVersion(36)
            }
        }
        if (project.state.executed) {
            applyCompileSdk.execute(this)
        } else {
            afterEvaluate(applyCompileSdk)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
