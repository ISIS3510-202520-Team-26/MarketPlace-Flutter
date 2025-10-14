class Failure implements Exception {
final String message; final int? status;
Failure(this.message, {this.status});
@override String toString() => 'Failure($status): $message';
}