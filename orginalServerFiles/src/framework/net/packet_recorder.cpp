#include <framework/global.h>
#include <framework/core/clock.h>
#include <framework/core/resourcemanager.h>

#include "packet_recorder.h"

PacketRecorder::PacketRecorder(const std::string& file)
{
    m_start = g_clock.millis();
    limitReplayFiles(7);
#ifdef ANDROID
    g_resources.makeDir(g_resources.getWriteDir() + "records");
    m_stream = std::ofstream(std::string("records/") + file);
#else
    std::error_code ec;
    std::string recordsPath = g_resources.getWriteDir() + "records";
    std::filesystem::create_directory(recordsPath, ec);
    m_stream = std::ofstream(std::filesystem::path(recordsPath) / file);
#endif
}

PacketRecorder::~PacketRecorder()
{

}

void PacketRecorder::addInputPacket(const InputMessagePtr& packet)
{
    m_stream << "< " << (g_clock.millis() - m_start) << " ";
    for (auto& buffer : packet->getBodyBuffer()) {
        m_stream << std::setfill('0') << std::setw(2) << std::hex << (uint16_t)(uint8_t)buffer;
    }
    m_stream << std::dec << "\n";
}

void PacketRecorder::addOutputPacket(const OutputMessagePtr& packet)
{
    if (m_firstOutput) {
        // skip packet with login and password
        m_firstOutput = false;
        return;
    }

    m_stream << "> " << (g_clock.millis() - m_start) << " ";
    for (auto& buffer : packet->getBuffer()) {
        m_stream << std::setfill('0') << std::setw(2) << std::hex << (uint16_t)(uint8_t)buffer;
    }
    m_stream << std::dec << "\n";
}

void PacketRecorder::limitReplayFiles(int maxFiles)
{
    std::string replayDir = g_resources.getWriteDir() + "records";
    std::vector<std::filesystem::path> replayFiles;


    for (const auto& entry : std::filesystem::directory_iterator(replayDir)) {
        if (entry.is_regular_file()) {
            replayFiles.push_back(entry.path());
        }
    }


    while (static_cast<int>(replayFiles.size()) > maxFiles) {
        std::sort(replayFiles.begin(), replayFiles.end(), [](const auto& a, const auto& b) {
            return std::filesystem::last_write_time(a) < std::filesystem::last_write_time(b);
        });

        std::filesystem::path oldestFile = replayFiles.front();
        std::filesystem::remove(oldestFile);
        replayFiles.erase(replayFiles.begin());
    }
}

