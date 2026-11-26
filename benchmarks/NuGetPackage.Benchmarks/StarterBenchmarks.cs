using BenchmarkDotNet.Attributes;

namespace Atya.Templates.NuGetPackage.Benchmarks;

// TODO: Replace this starter with benchmarks of your package's real public-API hot paths.
// Atya benchmark standard:
//   * [MemoryDiagnoser] on every class (allocations are first-class).
//   * Benchmark representative, real operations with meaningful [Params] input sizes.
//   * Add a realistic [Benchmark(Baseline = true)] alternative where a comparison teaches something.
//   * Build fixtures in [GlobalSetup]; return results so the JIT can't eliminate the work.
//   * Measure the success/hot path — not exception-throwing paths.
/// <summary>
/// Starter benchmarks for the generated package.
/// </summary>
[MemoryDiagnoser]
public class StarterBenchmarks
{
    private readonly string _value = "Atya.Templates.NuGetPackage";

    /// <summary>
    /// Reads the length of a representative value.
    /// </summary>
    /// <returns>The value length.</returns>
    [Benchmark]
    public int ReadStarterValueLength() => _value.Length;
}
