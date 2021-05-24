{% assign package_label = "zip" %}
{% assign pre_suffix = "" %}
{% assign package_url_template = "https://github.com/Azure/azure-sdk-for-c/archive/item.Version.zip" %}
<!--{% assign msdocs_url_template = "https://docs.microsoft.com/c/api/overview/azure/item.TrimmedPackage-readme" %}-->
{% assign ghdocs_url_template = "https://azuresdkdocs.blob.core.windows.net/$web/c/item.Package/item.Version/index.html" %}
{% assign source_url_template = "https://github.com/Azure/azure-sdk-for-c/tree/item.Version/sdk/item.RepoPath/" %}
{% assign changelog_blob_url_template = "https://github.com/Azure/azure-sdk-for-c/blob/item.Package_item.Version/sdk/item.RepoPath/item.Package/CHANGELOG.md" %}
{% assign changelog_raw_url_template = "https://raw.githubusercontent.com/Azure/azure-sdk-for-c/item.Package_item.Version/sdk/item.RepoPath/item.Package/CHANGELOG.md" %}