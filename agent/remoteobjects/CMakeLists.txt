cmake_minimum_required(VERSION 3.16)
project(DaemonAgentRemoteObjects VERSION 1.0.0 LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Core RemoteObjects)

# Generate Source and Replica from .rep file
qt6_add_repc_sources(daemon_agent_source DaemonAgent.rep)
qt6_add_repc_replicas(daemon_agent_replica DaemonAgent.rep)

# Source library (used by daemon-ai process)
add_library(DaemonAgentSource STATIC ${daemon_agent_source})
target_link_libraries(DaemonAgentSource PRIVATE Qt6::Core Qt6::RemoteObjects)

# Replica library (used by Basecamp)
add_library(DaemonAgentReplica STATIC ${daemon_agent_replica})
target_link_libraries(DaemonAgentReplica PRIVATE Qt6::Core Qt6::RemoteObjects)
