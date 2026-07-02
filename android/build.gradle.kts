allprojects {
    repositories {
        // Aliyun mirrors first for networks where dl.google.com /
        // repo.maven.apache.org suffer TLS handshake termination.
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
    }
}

// Legacy Flutter plugins (e.g. :home_widget) apply AGP via their own
// `buildscript { repositories { google() }}` block. Rewrite every project's
// buildscript repositories to use the Aliyun mirrors too, otherwise the AGP
// classpath JARs fail with TLS handshake errors against dl.google.com.
subprojects {
    buildscript {
        repositories {
            maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/public") }
            google()
            mavenCentral()
        }
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
