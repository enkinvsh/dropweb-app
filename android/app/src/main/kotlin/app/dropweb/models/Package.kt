package app.dropweb.models

data class Package(
    val packageName: String,
    val label: String,
    val system: Boolean,
    val internet: Boolean,
    val lastUpdateTime: Long,
)
