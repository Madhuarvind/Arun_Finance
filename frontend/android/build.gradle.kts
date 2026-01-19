allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://download.flutter.io") }
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

subprojects {
    project.configurations.all {
        resolutionStrategy {
            force("androidx.browser:browser:1.8.0")
            force("androidx.activity:activity:1.9.0")
            force("androidx.activity:activity-ktx:1.9.0")
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
        }
    }
}
