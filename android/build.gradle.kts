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

// 修复插件 JVM target 冲突：在所有项目评估完成后，强制问题插件的 Java/Kotlin 编译目标。
gradle.projectsEvaluated {
    subprojects {
        if (project.name in listOf("add_2_calendar", "receive_sharing_intent")) {
            project.tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = "17"
                targetCompatibility = "17"
            }
            project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
                .configureEach {
                    compilerOptions {
                        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                    }
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
