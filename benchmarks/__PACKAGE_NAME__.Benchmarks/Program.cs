using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;

namespace __PACKAGE_NAME__.Benchmarks;

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
    private const string Value = "__PACKAGE_NAME__";

    [Benchmark]
    public static int ReadStarterValueLength()
    {
        return Value.Length;
    }
}
