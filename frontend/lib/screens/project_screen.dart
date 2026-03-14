import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';

/// Project selection screen — first screen of the app.
class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key});

  static const _iconMap = <String, IconData>{
    'military_tech': Icons.military_tech,
    'rocket_launch': Icons.rocket_launch,
    'smart_toy': Icons.smart_toy,
    'precision_manufacturing': Icons.precision_manufacturing,
    'train': Icons.train,
  };

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfig>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade900, Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Icon(Icons.precision_manufacturing,
                        color: Colors.cyan, size: 32),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NL2Bot Controller',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('Select a project',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 14)),
                      ],
                    ),
                    const Spacer(),
                    // Settings
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white54),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/settings'),
                    ),
                  ],
                ),
              ),

              // Project list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: config.projects.length,
                  itemBuilder: (context, index) {
                    final project = config.projects[index];
                    final isDefault =
                        project.id == config.defaultProjectId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.grey.shade800.withValues(alpha: 0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDefault
                              ? Colors.cyan.withValues(alpha: 0.6)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/control',
                            arguments: project.id,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(
                                _iconMap[project.icon] ?? Icons.rocket_launch,
                                color: Colors.cyan,
                                size: 40,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(project.name,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(project.description,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                              if (isDefault)
                                Chip(
                                  label: const Text('DEFAULT',
                                      style: TextStyle(fontSize: 10)),
                                  backgroundColor:
                                      Colors.cyan.withValues(alpha: 0.2),
                                  side: BorderSide(
                                      color:
                                          Colors.cyan.withValues(alpha: 0.4)),
                                ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white38),
                                onSelected: (value) {
                                  if (value == 'default') {
                                    config.setDefaultProject(project.id,
                                        skip: true);
                                  } else if (value == 'clear_default') {
                                    config.setDefaultProject(null);
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (!isDefault)
                                    const PopupMenuItem(
                                      value: 'default',
                                      child:
                                          Text('Set as default (skip selection)'),
                                    ),
                                  if (isDefault)
                                    const PopupMenuItem(
                                      value: 'clear_default',
                                      child: Text('Clear default'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
