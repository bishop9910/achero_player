import com.android.build.api.dsl.LibraryExtension

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

// flutter_plugin_android_lifecycle 等插件要求 compileSdk >= 36，
// 这里统一把 Android 库插件子模块（file_picker、path_provider…）的 compileSdk 提到 36。
// 用 state.executed 判断避免对已求值的 project 调 afterEvaluate。
subprojects {
    if (project.state.executed) {
        if (project.plugins.hasPlugin("com.android.library")) {
            project.extensions.configure<LibraryExtension> {
                compileSdk = 36
            }
        }
    } else {
        project.afterEvaluate {
            if (project.plugins.hasPlugin("com.android.library")) {
                project.extensions.configure<LibraryExtension> {
                    compileSdk = 36
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
