namespace Atya.Templates.NuGetPackage.UnitTests;

public sealed class TemplateWiringTests
{
    [Fact]
    public void LibraryAssembly_Can_Be_Loaded()
    {
        var assembly = typeof(__PACKAGE_MARKER_NAME__Marker).Assembly;

        assembly.Should().NotBeNull();
        assembly.GetName().Name.Should().Be("Atya.Templates.NuGetPackage");
    }

    [Fact]
    public void Marker_Exposes_Package_Id()
    {
        __PACKAGE_MARKER_NAME__Marker.PackageId.Should().Be("Atya.Templates.NuGetPackage");
    }
}
