pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url = java.net.URI("https://jmrtd.org/maven/") }
        maven { url = java.net.URI("https://jitpack.io") }
        maven { url = java.net.URI("https://repo.maven.apache.org/maven2/") }
    }
}


rootProject.name = "IraqiNationalIdReader"
include(":app")
