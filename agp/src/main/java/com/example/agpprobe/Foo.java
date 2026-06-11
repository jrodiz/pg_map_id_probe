package com.example.agpprobe;
public class Foo {
  public int bar(int n) { return new Baz().compute(n) + 1; }
  public static void main(String[] a) { System.out.println(new Foo().bar(a.length)); }
}
class Baz {
  int compute(int n) { return n * 7 + helper(); }
  private int helper() { return 3; }
}
