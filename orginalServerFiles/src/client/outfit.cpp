/*
 * Copyright (c) 2010-2017 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "outfit.h"
#include "game.h"
#include "spritemanager.h"

#include <framework/graphics/painter.h>
#include <framework/graphics/drawcache.h>
#include <framework/graphics/drawqueue.h>
#include <framework/graphics/atlas.h>
#include <framework/graphics/texturemanager.h>
#include <framework/graphics/image.h>
#include <framework/graphics/framebuffermanager.h>
#include <framework/graphics/shadermanager.h>

Outfit::Outfit()
{
    m_category = ThingCategoryCreature;
    m_id = 128;
    m_auxId = 0;
    resetClothes();
}

void Outfit::draw(Point dest, Otc::Direction direction, uint walkAnimationPhase, bool animate, LightView* lightView, bool ui)
{
    // Correção da direção
    if (m_category != ThingCategoryCreature)
        direction = Otc::North;
    else if (direction == Otc::NorthEast || direction == Otc::SouthEast)
        direction = Otc::East;
    else if (direction == Otc::NorthWest || direction == Otc::SouthWest)
        direction = Otc::West;

    auto type = g_things.rawGetThingType(m_category == ThingCategoryCreature ? m_id : m_auxId, m_category);
    if (!type) {
        g_logger.error("Tipo de coisa (outfit) não encontrado.");
        return;
    }

    Point wingDest = dest;
    float wingsOpacity = 1.0f; // Opacidade padrão para wings

    if (m_wings) {
        auto wingsType = g_things.rawGetThingType(m_wings, ThingCategoryCreature);
        if (wingsType) {
            auto subDisplacementIt = type->getSubOutfitDisplacements().find(m_wings);
            if (subDisplacementIt != type->getSubOutfitDisplacements().end()) {
                const auto& subDisplacement = subDisplacementIt->second;
                wingsOpacity = subDisplacement.opacity;

                Point wingsDisplacement;
                switch (direction) {
                    case Otc::North: wingsDisplacement = subDisplacement.north; break;
                    case Otc::East: wingsDisplacement = subDisplacement.east; break;
                    case Otc::South: wingsDisplacement = subDisplacement.south; break;
                    case Otc::West: wingsDisplacement = subDisplacement.west; break;
                    default: wingsDisplacement = Point(0, 0); break;
                }

                wingDest += wingsDisplacement;
            }
        }
    }

    if (g_game.getFeature(Otc::GameCenteredOutfits)) {
        dest.x += ((type->getWidth() - 1) * (g_sprites.spriteSize() / 2));
    }

    Color color = Color::white;
    color.setAlpha(static_cast<uint8_t>(wingsOpacity * 255)); // Aplicação correta da opacidade das wings

    int animationPhase = walkAnimationPhase;

    auto wingBounce = [&] {
        int maxoffset = 4;
        uint floatingTicks = 8;
        uint tick = (g_clock.millis() % (1000)) / (1000 / floatingTicks);
        int offset = tick <= floatingTicks / 2 ? tick * (maxoffset / (floatingTicks / 2)) : (2 * maxoffset) - tick * (maxoffset / (floatingTicks / 2));
        dest -= Point(offset, offset) * g_sprites.getOffsetFactor();
        wingDest -= Point(offset, offset) * g_sprites.getOffsetFactor();
    };

    if (animate && m_category == ThingCategoryCreature) {
        auto idleAnimator = type->getIdleAnimator();
        if (idleAnimator && !ui) {
            animationPhase += walkAnimationPhase > 0 ? idleAnimator->getAnimationPhases() - 1 : idleAnimator->getPhase();
        } else if (type->isAnimateAlways() || ui) {
            int phases = type->getAnimator() ? type->getAnimator()->getAnimationPhases() : type->getAnimationPhases();
            if (ui && phases < 4) phases = 2;
            int ticksPerFrame = !g_game.getFeature(Otc::GameEnhancedAnimations) ? 333 : (1000 / phases);
            animationPhase = (g_clock.millis() % (ticksPerFrame * phases)) / ticksPerFrame;
            if (idleAnimator && ui) animationPhase += idleAnimator->getAnimationPhases() - 1;
            if (!type->isAnimateAlways() && ui) animationPhase += 1;
        }
        if (g_game.getFeature(Otc::GameWingOffset) && m_wings) {
            wingBounce();
        }
    } else if (animate) {
        int animationPhases = type->getAnimationPhases();
        int animateTicks = g_game.getFeature(Otc::GameEnhancedAnimations) ? Otc::ITEM_TICKS_PER_FRAME_FAST : Otc::ITEM_TICKS_PER_FRAME;

        if (m_category == ThingCategoryEffect) {
            animationPhases = std::max<int>(1, animationPhases - 2);
            animateTicks = g_game.getFeature(Otc::GameEnhancedAnimations) ? Otc::INVISIBLE_TICKS_PER_FRAME_FAST : Otc::INVISIBLE_TICKS_PER_FRAME;
        }

        if (animationPhases > 1)
            animationPhase = (g_clock.millis() % (animateTicks * animationPhases)) / animateTicks;
        if (m_category == ThingCategoryEffect)
            animationPhase = std::min<int>(animationPhase + 1, animationPhases);
    }

    int zPattern = m_mount > 0 ? std::min<int>(1, type->getNumPatternZ() - 1) : 0;
    float mountOpacity = 1.0f; // Opacidade padrão para mount
    auto drawMount = [&] {
        if (zPattern > 0) {
            int mountAnimationPhase = walkAnimationPhase;
            auto mountType = g_things.rawGetThingType(m_mount, ThingCategoryCreature);
            auto idleAnimator = mountType->getIdleAnimator();

            if (idleAnimator && animate) {
                mountAnimationPhase += walkAnimationPhase > 0 ? idleAnimator->getAnimationPhases() - 1 : idleAnimator->getPhase();
            } else if (ui && animate) {
                int phases = mountType->getAnimator() ? mountType->getAnimator()->getAnimationPhases() : mountType->getAnimationPhases();
                int ticksPerFrame = 1000 / phases;
                mountAnimationPhase = (g_clock.millis() % (ticksPerFrame * phases)) / ticksPerFrame;
                if (!mountType->isAnimateAlways()) mountAnimationPhase += 1;
            }
            if (m_wings && g_game.getFeature(Otc::GameWingOffset)) {
                mountAnimationPhase = idleAnimator ? idleAnimator->getPhase() : 0;
            }

            dest -= mountType->getDisplacement() * g_sprites.getOffsetFactor();

            Point mountDest = dest;
            auto subDisplacementIt = type->getSubOutfitDisplacements().find(m_mount);
            Point mountDisplacement;

            if (subDisplacementIt != type->getSubOutfitDisplacements().end()) {
                const auto& subDisplacement = subDisplacementIt->second;
                mountOpacity = subDisplacement.opacity;

                switch (direction) {
                    case Otc::North: mountDisplacement = subDisplacement.north; break;
                    case Otc::East: mountDisplacement = subDisplacement.east; break;
                    case Otc::South: mountDisplacement = subDisplacement.south; break;
                    case Otc::West: mountDisplacement = subDisplacement.west; break;
                    default: mountDisplacement = Point(0, 0); break;
                }

                mountDest += mountDisplacement;
            }

            Color mountColor = Color::white;
            mountColor.setAlpha(static_cast<uint8_t>(mountOpacity * 255)); // Aplica a opacidade correta do mount

            if (type->hasBones() && mountType->hasBones()) {
                auto outfitBones = type->getBones(direction);
                int bonusOffset = std::abs(mountType->getWidth() - type->getWidth()) * 32;
                auto mountBones = mountType->getBones(direction);
                auto boneOffset = Point((outfitBones.x - mountBones.x) + bonusOffset, (outfitBones.y - mountBones.y) + bonusOffset);

                mountDest += boneOffset * g_sprites.getOffsetFactor();
                mountType->draw(mountDest, 0, direction, 0, 0, mountAnimationPhase, mountColor, lightView);
            } else {
                mountType->draw(mountDest, 0, direction, 0, 0, mountAnimationPhase, mountColor, lightView);
            }
            dest += type->getDisplacement() * g_sprites.getOffsetFactor();
        }
    };

    auto drawWings = [&] {
        int wingAnimationPhase = walkAnimationPhase;
        auto wingsType = g_things.rawGetThingType(m_wings, ThingCategoryCreature);
        int wingsZPattern = m_mount > 0 ? std::min<int>(1, wingsType->getNumPatternZ() - 1) : 0;
        auto idleAnimator = wingsType->getIdleAnimator();

        if (animate) {
            wingAnimationPhase = idleAnimator ? (walkAnimationPhase > 0 ? idleAnimator->getAnimationPhases() - 1 : idleAnimator->getPhase()) : 0;
            if (wingsType->isAnimateAlways()) {
                int phases = wingsType->getAnimator() ? wingsType->getAnimator()->getAnimationPhases() : wingsType->getAnimationPhases();
                int ticksPerFrame = 1000 / phases;
                wingAnimationPhase = (g_clock.millis() % (ticksPerFrame * phases)) / ticksPerFrame;
            }
        }

        // Pega o deslocamento padrão das wings usando getSubOutfitDisplacements
        Point wingsDisplacement(0, 0);
        auto subDisplacementIt = type->getSubOutfitDisplacements().find(m_wings);
        if (subDisplacementIt != type->getSubOutfitDisplacements().end()) {
            const auto& subDisplacement = subDisplacementIt->second;
            wingsOpacity = subDisplacement.opacity;

            // Define o deslocamento da wing baseado na direção
            switch (direction) {
                case Otc::North: wingsDisplacement = subDisplacement.north; break;
                case Otc::East: wingsDisplacement = subDisplacement.east; break;
                case Otc::South: wingsDisplacement = subDisplacement.south; break;
                case Otc::West: wingsDisplacement = subDisplacement.west; break;
                default: wingsDisplacement = Point(0, 0); break;
            }
        }

        if (wingsDisplacement.x == 0 && wingsDisplacement.y == 0) {
            if (g_app.isHDMode()) {
                wingsDisplacement = Point(20, 25);
            }
        } else {
            if (g_app.isHDMode()) {
                wingsDisplacement.x /= 2;
                wingsDisplacement.y /= 2;
            } else {
                wingsDisplacement.x *= 2;
                wingsDisplacement.y *= 2;
            }
        }

        if (m_mount > 0) {
            if (direction == Otc::South) {
                wingsDisplacement.x -= 7; // Ajuste específico para South
                wingsDisplacement.y -= 17;
            } else if (direction == Otc::East) {
                wingsDisplacement.x -= 18; // Ajuste específico para East
                wingsDisplacement.y -= 7;
            }
        }

        // Aplica o deslocamento calculado às wings
        wingDest += wingsDisplacement * g_sprites.getOffsetFactor();

        // Desenha as wings com a opacidade correta
        Color wingColor = Color::white;
        wingColor.setAlpha(static_cast<uint8_t>(wingsOpacity * 255));
        wingsType->draw(wingDest, 0, direction, 0, wingsZPattern, wingAnimationPhase, wingColor, lightView);
    };

    Point auraDest = dest;
    float auraOpacity = 1.0f; // Opacidade padrão para aura
    auto drawAura = [&] {
        int auraAnimationPhase = 0;
        auto auraType = g_things.rawGetThingType(m_aura, ThingCategoryCreature);
        int auraZPattern = m_mount > 0 ? std::min<int>(1, auraType->getNumPatternZ() - 1) : 0;
        auto auraAnimator = auraType->getAnimator();

        if (animate) {
            if (auraType->isAnimateAlways()) {
                int phases = auraAnimator ? auraAnimator->getAnimationPhases() : auraType->getAnimationPhases();
                int ticksPerFrame = 1000 / phases;
                auraAnimationPhase = (g_clock.millis() % (ticksPerFrame * phases)) / ticksPerFrame;
            } else if (auraAnimator) {
                auraAnimationPhase = auraAnimator->getPhase();
            } else {
                auraAnimationPhase = (stdext::millis() / 75) % auraType->getAnimationPhases();
            }
        }

        auto auraDisplacementIt = type->getSubOutfitDisplacements().find(m_aura);
        Point auraDisplacement;

        if (auraDisplacementIt != type->getSubOutfitDisplacements().end()) {
            const auto& subDisplacement = auraDisplacementIt->second;
            auraOpacity = subDisplacement.opacity;

            switch (direction) {
                case Otc::North: auraDisplacement = subDisplacement.north; break;
                case Otc::East: auraDisplacement = subDisplacement.east; break;
                case Otc::South: auraDisplacement = subDisplacement.south; break;
                case Otc::West: auraDisplacement = subDisplacement.west; break;
                default: auraDisplacement = Point(0, 0); break;
            }
        }

        if (auraDisplacement.x == 0 && auraDisplacement.y == 0) {
            if (g_app.isHDMode()) {
                auraDisplacement = Point(20, 25);
            }
        } else {
            if (g_app.isHDMode()) {
                auraDisplacement.x *= 2;
                auraDisplacement.y *= 2;
            } else {
                auraDisplacement.x /= 2;
                auraDisplacement.y /= 2;
            }
        }

        auraDest += auraDisplacement * g_sprites.getOffsetFactor();

        Color auraColor = Color::white;
        auraColor.setAlpha(static_cast<uint8_t>(auraOpacity * 255)); // Aplica opacidade correta da aura
        auraDest += auraDisplacement;
        auraType->draw(auraDest, 0, direction, 0, auraZPattern, auraAnimationPhase, auraColor, lightView);
    };

    Point topAuraDest = dest;
    auto drawTopAura = [&] {
        int auraAnimationPhase = 0;
        auto auraType = g_things.rawGetThingType(m_aura, ThingCategoryCreature);
        auto auraAnimator = auraType->getAnimator();
        
        if (animate) {
            if (auraType->isAnimateAlways() && auraAnimator) {
                int phases = auraAnimator->getAnimationPhases();
                int ticksPerFrame = 1000 / phases;
                auraAnimationPhase = (g_clock.millis() % (ticksPerFrame * phases)) / ticksPerFrame;
            } else if (auraAnimator) {
                auraAnimationPhase = auraAnimator->getPhase();
            } else {
                int phases = auraType->getAnimationPhases();
                auraAnimationPhase = (g_clock.millis() / 75) % phases;
            }
        }

        auto subDisplacementIt = type->getSubOutfitDisplacements().find(m_aura);
        Point auraDisplacement;
        if (subDisplacementIt != type->getSubOutfitDisplacements().end()) {
            const auto& subDisplacement = subDisplacementIt->second;
            color.setAlpha(static_cast<uint8_t>(subDisplacement.opacity * 255));

            switch (direction) {
                case Otc::North: auraDisplacement = subDisplacement.north; break;
                case Otc::East: auraDisplacement = subDisplacement.east; break;
                case Otc::South: auraDisplacement = subDisplacement.south; break;
                case Otc::West: auraDisplacement = subDisplacement.west; break;
                default: auraDisplacement = Point(0, 0); break;
            }
        }

        if (g_app.isHDMode()) {
            auraDisplacement.x *= 2;
            auraDisplacement.y *= 2;
        }

        topAuraDest += auraDisplacement;

        auraType->draw(topAuraDest, 1, direction, 0, 0, auraAnimationPhase, color, lightView);
    };

    if (m_aura && g_game.getFeature(Otc::GameBigAurasCenter)) {
        auto auraType = g_things.rawGetThingType(m_aura, ThingCategoryCreature);
        if (auraType->getHeight() > 1 || auraType->getWidth() > 1) {
            Point offset = Point((auraType->getWidth() > 1 ? (auraType->getWidth() - 1) * 16 : 0), (auraType->getHeight() > 1 ? (auraType->getHeight() - 1) * 16 : 0));
            topAuraDest += offset * g_sprites.getOffsetFactor();
            auraDest += offset * g_sprites.getOffsetFactor();
        }
    }

    if (m_aura && (!g_game.getFeature(Otc::GameDrawAuraOnTop) || g_game.getFeature(Otc::GameAuraFrontAndBack))) {
        drawAura();
    }

    drawMount();

    if (m_wings && (direction == Otc::South || direction == Otc::East)) {
        drawWings();
    }

    Point center;
    for (int yPattern = 0; yPattern < type->getNumPatternY(); yPattern++) {
        if (yPattern > 0 && !(getAddons() & (1 << (yPattern - 1)))) {
            continue;
        }

        if (type->getLayers() <= 1) {
            if (!m_shader.empty()) {
                std::shared_ptr<DrawOutfitParams> outfitParams = type->drawOutfit(dest, 0, direction, yPattern, zPattern, animationPhase, color, lightView);
                if (!outfitParams) continue;
                if (yPattern == 0) center = outfitParams->dest.center();
                DrawQueueItemTexturedRect* outfit = new DrawQueueItemOutfitWithShader(outfitParams->dest, outfitParams->texture, outfitParams->src, outfitParams->offset, center, 0, m_shader, m_center);
                g_drawQueue->add(outfit);
                continue;
            }
            type->draw(dest, 0, direction, yPattern, zPattern, animationPhase, color, lightView);
            continue;
        }

        uint32_t colors = m_head + (m_body << 8) + (m_legs << 16) + (m_feet << 24);
        std::shared_ptr<DrawOutfitParams> outfitParams = type->drawOutfit(dest, 1, direction, yPattern, zPattern, animationPhase, color, lightView);
        if (!outfitParams) continue;

        DrawQueueItemTexturedRect* outfit = nullptr;
        if (m_shader.empty())
            outfit = new DrawQueueItemOutfit(outfitParams->dest, outfitParams->texture, outfitParams->src, outfitParams->offset, colors, outfitParams->color, m_center);
        else {
            if (yPattern == 0) center = outfitParams->dest.center();
            outfit = new DrawQueueItemOutfitWithShader(outfitParams->dest, outfitParams->texture, outfitParams->src, outfitParams->offset, center, colors, m_shader, m_center);
        }
        g_drawQueue->add(outfit);
    }

    if (m_wings && (direction == Otc::North || direction == Otc::West)) {
        drawWings();
    }
    
    if (m_aura && (g_game.getFeature(Otc::GameDrawAuraOnTop) || g_game.getFeature(Otc::GameAuraFrontAndBack))) {
        if (g_game.getFeature(Otc::GameAuraFrontAndBack)) {
            if (zPattern > 0) {
                if (direction == Otc::East)
                    topAuraDest -= Point(12, 6) * g_sprites.getOffsetFactor();
                else if (direction == Otc::South)
                    topAuraDest -= Point(1, 12) * g_sprites.getOffsetFactor();
                else
                    topAuraDest -= Point(4, 6) * g_sprites.getOffsetFactor();
            }
            drawTopAura();
        } else {
            drawAura();
        }
    }
}


void Outfit::draw(const Rect& dest, Otc::Direction direction, uint animationPhase, bool animate, bool ui, bool oldScaling)
{
    int size = g_drawQueue->size();
    draw(Point(0, 0), direction, animationPhase, animate, nullptr, ui);
    g_drawQueue->correctOutfit(dest, size, oldScaling);
}

void Outfit::resetClothes()
{
    setHead(0);
    setBody(0);
    setLegs(0);
    setFeet(0);
    setMount(0);
    setWings(0);
    setAura(0);
    resetShader();
}

// drawing

bool DrawQueueItemOutfit::cache()
{
    m_texture->update();
    uint64_t hash = (((uint64_t)m_texture->getUniqueId()) << 48) +
        (((uint64_t)m_src.x()) << 36) +
        (((uint64_t)m_src.y()) << 24) +
        (((uint64_t)m_src.width()) << 12) +
        (((uint64_t)m_src.height())) +
        (((uint64_t)m_colors) * 1125899906842597ULL);
    bool drawNow = false;
    Point atlasPos = g_atlas.cache(hash, m_src.size(), drawNow);
    if (atlasPos.x < 0) { return false; } // can't be cached
    if (drawNow) { g_drawCache.bind(); draw(atlasPos); }

    if (!g_drawCache.hasSpace(6))
        return false;

    g_drawCache.addTexturedRect(m_dest, Rect(atlasPos, m_src.size()), m_color);
    return true;
}

void DrawQueueItemOutfit::draw()
{
    if (!m_texture) return;
    Matrix4 mat4;
    for (int x = 0; x < 4; ++x) {
        Color color = Color::getOutfitColor((m_colors >> (x * 8)) & 0xFF);
        mat4(x + 1, 1) = color.rF();
        mat4(x + 1, 2) = color.gF();
        mat4(x + 1, 3) = color.bF();
        mat4(x + 1, 4) = color.aF();
    }
    g_painter->setDrawOutfitLayersProgram();
    g_painter->setMatrixColor(mat4);
    g_painter->setOffset(m_offset);
    g_painter->drawTexturedRect(m_dest, m_texture, m_src);
    g_painter->resetShaderProgram();
}

void DrawQueueItemOutfit::draw(const Point& pos)
{
    if (!m_texture) return;
    Matrix4 mat4;
    for (int x = 0; x < 4; ++x) {
        Color color = Color::getOutfitColor((m_colors >> (x * 8)) & 0xFF);
        mat4(x + 1, 1) = color.rF();
        mat4(x + 1, 2) = color.gF();
        mat4(x + 1, 3) = color.bF();
        mat4(x + 1, 4) = color.aF();
    }
    g_painter->setDrawOutfitLayersProgram();
    g_painter->setMatrixColor(mat4);
    g_painter->setOffset(m_offset);
    g_painter->drawTexturedRect(Rect(pos, m_src.size()), m_texture, m_src);
    g_painter->resetShaderProgram();
}

void DrawQueueItemOutfitWithShader::draw()
{
    if (!m_texture) return;
    PainterShaderProgramPtr shader = g_shaders.getShader(m_shader);
    if (!shader) return DrawQueueItemTexturedRect::draw();
    bool useFramebuffer = m_dest.size() != m_src.size();

    if (useFramebuffer) {
        g_framebuffers.getTemporaryFrameBuffer()->resize(m_src.size());
        g_framebuffers.getTemporaryFrameBuffer()->bind();
        g_painter->clear(Color::alpha);
    }

    Matrix4 mat4;
    for (int x = 0; x < 4; ++x) {
        Color color = Color::getOutfitColor((m_colors >> (x * 8)) & 0xFF);
        mat4(x + 1, 1) = color.rF();
        mat4(x + 1, 2) = color.gF();
        mat4(x + 1, 3) = color.bF();
        mat4(x + 1, 4) = color.aF();
    }
    g_painter->setShaderProgram(shader);
    g_painter->setOffset(m_offset);
    shader->setMatrixColor(mat4);
    shader->setCenter(m_center);
    shader->bindMultiTextures();
    if (useFramebuffer) {
        g_painter->drawTexturedRect(Rect(0, 0, m_src.size()), m_texture, m_src);
    } else {
        g_painter->drawTexturedRect(m_dest, m_texture, m_src);
    }
    g_painter->resetShaderProgram();

    if (useFramebuffer) {
        g_framebuffers.getTemporaryFrameBuffer()->release();
        g_painter->resetColor();
        g_framebuffers.getTemporaryFrameBuffer()->draw(m_dest);
    }
}
