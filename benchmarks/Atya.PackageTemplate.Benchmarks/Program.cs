using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;

namespace Atya.PackageTemplate.Benchmarks;

public static class Program
{
    public static void Main(string[] args)
    {
        _ = args;
        BenchmarkRunner.Run<TemplateBenchmarks>();
    }
}

[MemoryDiagnoser]
public class TemplateBenchmarks
{
    private readonly string _value = "Atya.PackageTemplate";

    [Benchmark]
    public int ReadStarterValueLength()
    {
        return _value.Length;
    }
}
