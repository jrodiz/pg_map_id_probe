public class Hello {
  public static void main(String[] a){ System.out.println(new Helper().greet(a.length)); }
}
class Helper {
  String greet(int n){ return "hi " + secret(n); }
  private int secret(int n){ return 42 + n; }
}
