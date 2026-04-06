import '../models/job.dart';

class JobService {
  final List<Job> jobs;

  JobService({required this.jobs});

  List<Job> getAllJobs() {
    return jobs;
  }

  void addJob(Job job) {
    jobs.add(job);
  }

  double getTotalRevenue() {
    return jobs.fold(0.0, (sum, job) => sum + job.price);
  }

  List<Job> getCompletedJobs() {
    return jobs
        .where((job) => job.status.toLowerCase() == 'completed')
        .toList();
  }

  List<Job> getActiveJobs() {
    return jobs
        .where((job) => job.status.toLowerCase() != 'completed')
        .toList();
  }

  Job? getJobById(String jobId) {
    try {
      return jobs.firstWhere((job) => job.id == jobId);
    } catch (e) {
      return null;
    }
  }
}