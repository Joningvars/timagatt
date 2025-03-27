import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_clock_provider.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/screens/job/shared_jobs_screen.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({Key? key}) : super(key: key);

  @override
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Job List')),
      body: _buildJobList(),
    );
  }

  Widget _buildJobList() {
    return Consumer<TimeClockProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            Expanded(child: _buildJobItems(provider)),
            _buildSharedJobsButton(context),
          ],
        );
      },
    );
  }

  Widget _buildJobItems(TimeClockProvider provider) {
    return ListView.builder(
      itemCount: provider.jobs.length,
      itemBuilder: (context, index) {
        final job = provider.jobs[index];
        return _buildJobItem(job);
      },
    );
  }

  Widget _buildJobItem(Job job) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: job.color, shape: BoxShape.circle),
      ),
      title: Text(job.name),
      trailing:
          job.isShared
              ? Tooltip(
                message: 'Shared Job',
                child: Icon(Icons.group, color: Colors.blue),
              )
              : null,
      onTap: () {
        // Handle job selection
      },
    );
  }

  Widget _buildSharedJobsButton(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SharedJobsScreen()),
          );
        },
        icon: const Icon(Icons.group_work),
        label: Text(provider.translate('sharedJobs')),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
