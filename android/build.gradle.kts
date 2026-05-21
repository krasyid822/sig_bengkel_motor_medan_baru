import com.android.build.gradle.BaseExtension

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
    
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }

    val configureAndroidJava = {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as BaseExtension
            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_21
                targetCompatibility = JavaVersion.VERSION_21
            }
        }

        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "21"
            targetCompatibility = "21"
        }

        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
            }
        }
    }

    if (project.state.executed) {
        configureAndroidJava()
    } else {
        project.afterEvaluate {
            configureAndroidJava()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
